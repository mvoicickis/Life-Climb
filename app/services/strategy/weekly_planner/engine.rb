# frozen_string_literal: true

module Strategy
  module WeeklyPlanner
    # Scripted, resumable weekly sitting planner.
    # #current presents the next step; #answer! writes and advances the cursor.
    class Engine
      Step = Struct.new(
        :template_id,
        :kind,
        :question,
        :status,
        :notice,
        :title,
        :source_options,
        :count_options,
        :eligible_dates,
        :sitting_count,
        :weekday_hint,
        :framing_line,
        :cap_note,
        keyword_init: true
      ) do
        def completed?
          status.to_s == "completed"
        end

        def week_nearly_done?
          kind.to_s == "week_nearly_done"
        end

        def week_exhausted?
          kind.to_s == "week_exhausted"
        end

        def terminal?
          completed? || week_nearly_done? || week_exhausted?
        end
      end

      AnswerResult = Struct.new(:ack, :next_step, :noop, keyword_init: true) do
        def noop?
          noop
        end
      end

      def self.current(user:, journey:, plan_id: nil)
        new(user:, journey:, plan_id:).current
      end

      def self.answer!(user:, journey:, value:, plan_id: nil)
        new(user:, journey:, plan_id:).answer!(value)
      end

      def self.restart!(user:, journey:, plan_id: nil)
        new(user:, journey:, plan_id:).restart!
      end

      def initialize(user:, journey:, plan_id: nil)
        @user = user
        @journey = journey
        @plan_id = plan_id.presence&.to_i
      end

      def current
        plan = resolve_plan
        return nil if plan.blank?

        eligible = Definition.eligible_dates(@user)
        return build_week_nearly_done_step if Definition.week_nearly_done?(eligible)
        return build_week_exhausted_step if eligible.empty?

        project = resolve_project(plan)
        return build_need_project_step if project.blank?

        data = Cursor.load(@journey)
        data = Cursor.start!(@journey, plan: plan) if data.blank?
        data = ensure_plan_project!(data, plan, project)

        data, healed = sanitize_cursor!(data, plan, project, eligible)
        Cursor.save!(@journey, data) if healed

        build_step(data, plan: plan, project: project, eligible: eligible,
                   notice: healed ? I18n.t("strategy.weekly_planner.shell.tree_changed") : nil)
      end

      def restart!
        plan = resolve_plan
        raise ArgumentError, I18n.t("strategy.weekly_planner.shell.need_plan") if plan.blank?

        data = Cursor.load(@journey)
        if data.blank? || data["status"] == "completed"
          Cursor.start!(@journey, plan: plan)
        end
        current
      end

      def answer!(value)
        plan = resolve_plan
        raise ArgumentError, I18n.t("strategy.weekly_planner.shell.need_plan") if plan.blank?

        eligible = Definition.eligible_dates(@user)
        if Definition.week_nearly_done?(eligible)
          return AnswerResult.new(ack: nil, next_step: build_week_nearly_done_step, noop: true)
        end
        if eligible.empty?
          return AnswerResult.new(ack: nil, next_step: build_week_exhausted_step, noop: true)
        end

        project = resolve_project(plan)
        raise ArgumentError, I18n.t("strategy.weekly_planner.errors.missing_project") if project.blank?

        @journey.with_lock do
          @journey.reload
          data = Cursor.load(@journey)
          data = Cursor.start!(@journey, plan: plan) if data.blank?
          data = ensure_plan_project!(data, plan, project)

          data, healed = sanitize_cursor!(data, plan, project, eligible)
          Cursor.save!(@journey, data) if healed

          if data["status"] == "completed"
            return AnswerResult.new(
              ack: I18n.t("strategy.weekly_planner.shell.done_flash",
                          count: data["sitting_count"].to_i,
                          title: data["title"].to_s),
              next_step: build_step(data, plan: plan, project: project, eligible: eligible),
              noop: true
            )
          end

          template = Definition.template(data["template_id"])
          key = Cursor.cursor_key(data)

          if data["answered_key"] == key
            data = heal_answered_write_step(data, template)
            Cursor.save!(@journey, data)
            return AnswerResult.new(
              ack: I18n.t("strategy.weekly_planner.acks.locked"),
              next_step: build_step(data, plan: plan, project: project, eligible: eligible),
              noop: true
            )
          end

          data = apply_answer!(data, template, value, plan: plan, project: project, eligible: eligible)
          data["answered_key"] = key
          Cursor.save!(@journey, data)
          AnswerResult.new(
            ack: ack_for(data),
            next_step: build_step(data, plan: plan, project: project, eligible: eligible),
            noop: false
          )
        end
      end

      private

      def resolve_plan
        area = @journey.life_area
        goal = @user.strategy_goals.for_area(area.id).for_kind("goal").roots.first
        return nil if goal.blank?

        plans = goal.children.select(&:plan?).sort_by { |p| [ p.position.to_i, p.id ] }
        return nil if plans.empty?

        if @plan_id.present?
          found = plans.find { |p| p.id == @plan_id }
          return found if found
        end

        data = Cursor.load(@journey)
        if data && data["plan_id"].present?
          found = plans.find { |p| p.id == data["plan_id"] }
          return found if found
        end

        plans.find { |p| !p.completed? } || plans.first
      end

      def resolve_project(plan)
        trail = Strategy::Trail.for(plan: plan)
        trail.current_node&.record
      end

      def ensure_plan_project!(data, plan, project)
        data.merge(
          "plan_id" => plan.id,
          "project_id" => project.id
        )
      end

      def sanitize_cursor!(data, plan, project, eligible)
        data = data.stringify_keys
        return [ data, false ] if data["status"] == "completed"

        healed = false
        template_id = data["template_id"].to_s

        if data["plan_id"].present? && data["plan_id"] != plan.id
          data = {
            "version" => Cursor::VERSION,
            "status" => "in_progress",
            "template_id" => "pick_source",
            "plan_id" => plan.id,
            "project_id" => project.id,
            "title" => nil,
            "source_practice_task_id" => nil,
            "sitting_count" => nil,
            "selected_dates" => [],
            "answered_key" => nil
          }
          return [ data, true ]
        end

        max = Definition.max_sittings(@journey, eligible)
        if data["sitting_count"].present? && data["sitting_count"].to_i > max && max >= 1
          data = data.merge(
            "template_id" => "pick_count",
            "sitting_count" => nil,
            "selected_dates" => [],
            "answered_key" => nil
          )
          healed = true
          template_id = "pick_count"
        end

        if %w[pick_count pick_days].include?(template_id) && data["title"].blank?
          data = data.merge(
            "template_id" => "pick_source",
            "sitting_count" => nil,
            "selected_dates" => [],
            "answered_key" => nil
          )
          healed = true
        elsif template_id == "pick_days" && data["sitting_count"].blank?
          data = data.merge(
            "template_id" => "pick_count",
            "selected_dates" => [],
            "answered_key" => nil
          )
          healed = true
        end

        [ data.merge("project_id" => project.id, "plan_id" => plan.id), healed ]
      end

      def heal_answered_write_step(data, template)
        return data unless Definition.write_kind?(template.kind)
        return data unless data["template_id"] == template.id

        nxt = Definition.next_after_write(template.id)
        return data if nxt.blank?

        data.merge("template_id" => nxt)
      end

      def apply_answer!(data, template, value, plan:, project:, eligible:)
        case template.kind
        when "pick_source"
          apply_pick_source!(data, value, project: project)
        when "pick_count"
          apply_pick_count!(data, value, eligible: eligible)
        when "pick_days"
          apply_pick_days!(data, value, plan: plan, project: project, eligible: eligible)
        else
          raise ArgumentError, "unknown write kind: #{template.kind}"
        end
      end

      def apply_pick_source!(data, value, project:)
        raw = value.to_s.strip
        raise ArgumentError, I18n.t("strategy.weekly_planner.errors.blank_title") if raw.blank?

        title = nil
        task_id = nil

        if (match = raw.match(/\Atask:(\d+)\z/))
          task = incomplete_tasks_for(project).find { |t| t.id == match[1].to_i }
          raise ArgumentError, I18n.t("strategy.weekly_planner.errors.bad_source") if task.blank?

          title = task.title
          task_id = task.id
        else
          title = raw.delete_prefix("other:").strip
          raise ArgumentError, I18n.t("strategy.weekly_planner.errors.blank_title") if title.blank?
        end

        data.merge(
          "title" => title,
          "source_practice_task_id" => task_id,
          "template_id" => Definition.next_after_write("pick_source"),
          "sitting_count" => nil,
          "selected_dates" => []
        )
      end

      def apply_pick_count!(data, value, eligible:)
        begin
          count = Integer(value.to_s.strip)
        rescue ArgumentError, TypeError
          raise ArgumentError, I18n.t("strategy.weekly_planner.errors.bad_count")
        end

        max = Definition.max_sittings(@journey, eligible)
        unless count.between?(1, max)
          raise ArgumentError, I18n.t("strategy.weekly_planner.errors.bad_count")
        end

        data.merge(
          "sitting_count" => count,
          "template_id" => Definition.next_after_write("pick_count"),
          "selected_dates" => []
        )
      end

      def apply_pick_days!(data, value, plan:, project:, eligible:)
        dates = parse_day_values(value)
        count = data["sitting_count"].to_i
        if dates.size != count || dates.any? { |d| !eligible.include?(d) }
          raise ArgumentError, I18n.t("strategy.weekly_planner.errors.bad_dates")
        end

        updated = data.merge(
          "selected_dates" => dates.map(&:iso8601),
          "plan_id" => plan.id,
          "project_id" => project.id
        )
        Writer.call(user: @user, journey: @journey, cursor: updated)
      end

      def parse_day_values(value)
        list =
          case value
          when Array then value
          else value.to_s.split(/[\s,]+/)
          end
        list.filter_map do |v|
          Date.iso8601(v.to_s)
        rescue ArgumentError, TypeError
          nil
        end.uniq
      end

      def incomplete_tasks_for(project)
        leaf = existing_practice_leaf(project)
        return PracticeTask.none if leaf.blank?

        host = existing_checklist_host(leaf)
        return PracticeTask.none if host.blank?

        host.practice_tasks.incomplete.ordered
      end

      # Read-only — do not create nested camps or checklist hosts while presenting.
      def existing_practice_leaf(project)
        return project if project.parent&.project?

        kids = project.children.select(&:project?)
        kids.find(&:leaf_checkpoint?) || kids.first
      end

      def existing_checklist_host(leaf)
        days = leaf.children.select(&:day?)
        days.find { |d| Strategy::EnsureFolderQuest.checklist_host?(d) } || days.first
      end

      def build_step(data, plan:, project:, eligible:, notice: nil)
        data = data.stringify_keys
        if data["status"] == "completed"
          return Step.new(
            template_id: data["template_id"],
            kind: "completed",
            question: nil,
            status: "completed",
            notice: notice,
            title: data["title"],
            sitting_count: data["sitting_count"].to_i,
            eligible_dates: eligible,
            source_options: nil,
            count_options: nil,
            weekday_hint: nil,
            framing_line: nil,
            cap_note: nil
          )
        end

        template = Definition.template(data["template_id"])
        max = Definition.max_sittings(@journey, eligible)

        if template.kind == "pick_count" && max < 1
          return build_week_exhausted_step
        end

        Step.new(
          template_id: template.id,
          kind: template.kind,
          question: question_for(template, data),
          status: data["status"],
          notice: notice,
          title: data["title"],
          source_options: source_options_for(template, project),
          count_options: count_options_for(template, max),
          eligible_dates: eligible,
          sitting_count: data["sitting_count"],
          weekday_hint: weekday_hint_for(template),
          framing_line: framing_for(template),
          cap_note: cap_note_for(template, max, eligible)
        )
      end

      def question_for(template, data)
        if template.kind == "pick_days"
          I18n.t(template.question_key, count: data["sitting_count"].to_i)
        else
          I18n.t(template.question_key)
        end
      end

      def source_options_for(template, project)
        return nil unless template.kind == "pick_source"

        incomplete_tasks_for(project).map do |task|
          { value: "task:#{task.id}", label: task.title }
        end
      end

      def count_options_for(template, max)
        return nil unless template.kind == "pick_count"
        return [] if max < 1

        (1..max).map { |n| { value: n.to_s, label: n.to_s } }
      end

      def weekday_hint_for(template)
        return nil unless template.kind == "pick_days"

        rates = Patterns::BattleStats.weekday_rates(@user)
        return nil if rates.blank?

        best = rates.max_by { |r| r[:rate] }
        return nil if best.blank?

        day_name = I18n.t("date.day_names")[best[:wday]]
        I18n.t("strategy.weekly_planner.hints.weekday", day: day_name)
      end

      def framing_for(template)
        return nil unless template.kind == "pick_source"

        I18n.t("strategy.weekly_planner.shell.framing")
      end

      def cap_note_for(template, max, eligible)
        return nil unless template.kind == "pick_count"
        return nil unless max < @journey.commitment_battle_count.to_i && max == eligible.size

        I18n.t("strategy.weekly_planner.shell.cap_note", count: max)
      end

      def build_week_nearly_done_step
        Step.new(
          template_id: nil,
          kind: "week_nearly_done",
          question: I18n.t("strategy.weekly_planner.shell.week_nearly_done_title"),
          status: "week_nearly_done",
          notice: I18n.t("strategy.weekly_planner.shell.week_nearly_done_body"),
          title: nil,
          source_options: nil,
          count_options: nil,
          eligible_dates: [],
          sitting_count: nil,
          weekday_hint: nil,
          framing_line: nil,
          cap_note: nil
        )
      end

      def build_week_exhausted_step
        Step.new(
          template_id: nil,
          kind: "week_exhausted",
          question: I18n.t("strategy.weekly_planner.shell.week_exhausted_title"),
          status: "week_exhausted",
          notice: I18n.t("strategy.weekly_planner.shell.week_exhausted_body"),
          title: nil,
          source_options: nil,
          count_options: nil,
          eligible_dates: [],
          sitting_count: nil,
          weekday_hint: nil,
          framing_line: nil,
          cap_note: nil
        )
      end

      def build_need_project_step
        Step.new(
          template_id: nil,
          kind: "week_exhausted",
          question: I18n.t("strategy.weekly_planner.shell.need_project_title"),
          status: "week_exhausted",
          notice: I18n.t("strategy.weekly_planner.shell.need_project_body"),
          title: nil,
          source_options: nil,
          count_options: nil,
          eligible_dates: [],
          sitting_count: nil,
          weekday_hint: nil,
          framing_line: nil,
          cap_note: nil
        )
      end

      def ack_for(data)
        if data["status"] == "completed"
          I18n.t(
            "strategy.weekly_planner.shell.done_flash",
            count: data["sitting_count"].to_i,
            title: data["title"].to_s
          )
        else
          I18n.t("strategy.weekly_planner.acks.locked")
        end
      end
    end
  end
end
