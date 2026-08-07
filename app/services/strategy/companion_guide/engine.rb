# frozen_string_literal: true

module Strategy
  module CompanionGuide
    # Scripted, resumable guide: #current presents the next step; #answer! writes
    # (or branches) and advances the setup_flags cursor.
    class Engine
      Step = Struct.new(
        :template_id, :kind, :question, :answer_options, :project_count, :step_count, :status, :notice,
        keyword_init: true
      ) do
        def completed?
          status.to_s == "completed"
        end
      end

      AnswerResult = Struct.new(:ack, :next_step, :noop, keyword_init: true) do
        def noop?
          noop
        end
      end

      NEEDS_PLAN = %w[set_effort_tier create_project create_day continue_step continue_project].freeze
      NEEDS_PROJECT = %w[create_day continue_step].freeze

      def self.current(user:, journey:)
        new(user:, journey:).current
      end

      def self.answer!(user:, journey:, value:)
        new(user:, journey:).answer!(value)
      end

      # Fresh guide run for "add another Plan". Only resets the cursor blob —
      # never touches StrategyGoal rows from a prior completed run.
      # No-ops (returns current) when a run is already in_progress.
      def self.restart!(user:, journey:)
        new(user:, journey:).restart!
      end

      def initialize(user:, journey:)
        @user = user
        @journey = journey
      end

      def current
        goal = resolve_goal
        return nil if goal.blank?

        data = Cursor.load(@journey)
        data = Cursor.start!(@journey, goal: goal) if data.blank?

        data, healed = sanitize_cursor!(data)
        Cursor.save!(@journey, data) if healed

        build_step(data, notice: healed ? tree_changed_notice : nil)
      end

      def restart!
        goal = resolve_goal
        raise ArgumentError, I18n.t("strategy.need_goal") if goal.blank?

        data = Cursor.load(@journey)
        if data.blank? || data["status"] == "completed"
          Cursor.start!(@journey, goal: goal)
        end
        current
      end

      def answer!(value)
        goal = resolve_goal
        raise ArgumentError, I18n.t("strategy.need_goal") if goal.blank?

        @journey.with_lock do
          @journey.reload
          data = Cursor.load(@journey)
          data = Cursor.start!(@journey, goal: goal) if data.blank?

          data, healed = sanitize_cursor!(data)
          Cursor.save!(@journey, data) if healed

          if data["status"] == "completed"
            return AnswerResult.new(ack: Copy.ack, next_step: build_step(data), noop: true)
          end

          template = Definition.template(data["template_id"])
          key = Cursor.cursor_key(data)

          if data["answered_key"] == key
            data = heal_answered_write_step(data, template)
            Cursor.save!(@journey, data)
            return AnswerResult.new(ack: Copy.ack, next_step: build_step(data), noop: true)
          end

          # Re-entry: plan already created for this run but cursor still on create_plan.
          if template.kind == "create_plan" && data["plan_id"].present?
            data = data.merge(
              "template_id" => Definition.next_after_write("create_plan"),
              "answered_key" => key
            )
            Cursor.save!(@journey, data)
            return AnswerResult.new(ack: Copy.ack, next_step: build_step(data), noop: true)
          end

          data = apply_answer!(data, template, value)
          data["answered_key"] = key
          Cursor.save!(@journey, data)
          AnswerResult.new(ack: Copy.ack, next_step: build_step(data), noop: false)
        end
      end

      private

      def resolve_goal
        area = @journey.life_area
        @user.strategy_goals.for_area(area.id).for_kind("goal").roots.first
      end

      def sanitize_cursor!(data)
        data = data.stringify_keys
        return [ data, false ] if data["status"] == "completed"

        healed = false
        template_id = data["template_id"].to_s
        plan = find_owned_plan(data["plan_id"])
        project = find_owned_project(data["project_id"])

        if data["plan_id"].present? && plan.blank?
          data = data.merge(
            "template_id" => "create_plan",
            "plan_id" => nil,
            "project_id" => nil,
            "project_count" => 0,
            "step_count" => 0,
            "answered_key" => nil
          )
          healed = true
          template_id = "create_plan"
          project = nil
        elsif data["project_id"].present? && project.blank?
          if plan.present? && NEEDS_PROJECT.include?(template_id)
            data = data.merge(
              "template_id" => "create_project",
              "project_id" => nil,
              "step_count" => 0,
              "answered_key" => nil
            )
            healed = true
            template_id = "create_project"
          elsif plan.blank?
            data = data.merge(
              "template_id" => "create_plan",
              "plan_id" => nil,
              "project_id" => nil,
              "project_count" => 0,
              "step_count" => 0,
              "answered_key" => nil
            )
            healed = true
            template_id = "create_plan"
          else
            # Stale project id while on a plan-only step — drop the id only.
            data = data.merge("project_id" => nil, "step_count" => 0)
            healed = true
          end
        end

        # Cursor points at a step that needs a parent that was never set / cleared.
        if NEEDS_PLAN.include?(template_id) && data["plan_id"].blank?
          data = data.merge(
            "template_id" => "create_plan",
            "project_id" => nil,
            "project_count" => 0,
            "step_count" => 0,
            "answered_key" => nil
          )
          healed = true
          template_id = "create_plan"
        elsif NEEDS_PROJECT.include?(template_id) && data["project_id"].blank? && data["plan_id"].present?
          data = data.merge(
            "template_id" => "create_project",
            "step_count" => 0,
            "answered_key" => nil
          )
          healed = true
        end

        [ data, healed ]
      end

      def find_owned_plan(id)
        return nil if id.blank?

        @user.strategy_goals.for_kind("plan").find_by(id: id)
      end

      def find_owned_project(id)
        return nil if id.blank?

        @user.strategy_goals.for_kind("project").find_by(id: id)
      end

      def tree_changed_notice
        I18n.t("strategy.companion_guide.shell.tree_changed")
      end

      def heal_answered_write_step(data, template)
        return data unless Definition.write_kind?(template.kind)
        return data unless data["template_id"] == template.id

        data.merge("template_id" => Definition.next_after_write(template.id))
      end

      def apply_answer!(data, template, value)
        if Definition.decision_kind?(template.kind)
          apply_decision!(data, template, value)
        else
          apply_write!(data, template, value)
        end
      end

      def apply_write!(data, template, value)
        updated = Writer.call(
          user: @user,
          journey: @journey,
          kind: template.kind,
          value: value,
          cursor: data
        ).stringify_keys
        updated.merge("template_id" => Definition.next_after_write(template.id))
      end

      def apply_decision!(data, template, value)
        decision = value.to_s.strip
        unless Definition::DECISION_VALUES.include?(decision)
          raise ArgumentError, I18n.t("strategy.companion_guide.errors.bad_decision")
        end

        decision = coerce_ceiling(data, template, decision)

        case template.kind
        when "continue_step"
          if decision == "repeat"
            data.merge("template_id" => "create_day")
          else
            data.merge("template_id" => "continue_project")
          end
        when "continue_project"
          if decision == "repeat"
            data.merge(
              "template_id" => "create_project",
              "project_id" => nil,
              "step_count" => 0
            )
          else
            data.merge("status" => "completed")
          end
        else
          raise ArgumentError, "unknown decision kind: #{template.kind}"
        end
      end

      def coerce_ceiling(data, template, decision)
        return decision unless decision == "repeat"

        case template.kind
        when "continue_step"
          return "advance" if data["step_count"].to_i >= Definition::MAX_STEPS_PER_PROJECT
        when "continue_project"
          return "advance" if data["project_count"].to_i >= Definition::MAX_PROJECTS
        end
        decision
      end

      def build_step(data, notice: nil)
        data = data.stringify_keys
        if data["status"] == "completed"
          return Step.new(
            template_id: data["template_id"],
            kind: "completed",
            question: nil,
            answer_options: nil,
            project_count: data["project_count"].to_i,
            step_count: data["step_count"].to_i,
            status: "completed",
            notice: notice
          )
        end

        template = Definition.template(data["template_id"])
        Step.new(
          template_id: template.id,
          kind: template.kind,
          question: I18n.t(template.question_key),
          answer_options: answer_options_for(template),
          project_count: data["project_count"].to_i,
          step_count: data["step_count"].to_i,
          status: data["status"],
          notice: notice
        )
      end

      def answer_options_for(template)
        return nil if template.answer_keys.blank?

        case template.kind
        when "set_effort_tier"
          StrategyGoal::EFFORT_TIERS.map do |tier|
            { value: tier, label: I18n.t("strategy.companion_guide.answers.effort_tier.#{tier}") }
          end
        when "continue_step"
          [
            { value: "repeat", label: I18n.t("strategy.companion_guide.answers.continue.repeat_step") },
            { value: "advance", label: I18n.t("strategy.companion_guide.answers.continue.advance_step") }
          ]
        when "continue_project"
          [
            { value: "repeat", label: I18n.t("strategy.companion_guide.answers.continue.repeat_project") },
            { value: "advance", label: I18n.t("strategy.companion_guide.answers.continue.advance_project") }
          ]
        end
      end
    end
  end
end
