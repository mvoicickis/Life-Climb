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
        :items,
        :item_index,
        :item_progress,
        :suggestions,
        :already_this_week,
        :eligible_dates,
        :weekday_hint,
        :framing_line,
        :cap_note,
        :created_count,
        :skipped,
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

        base_eligible = Definition.eligible_dates(@user)
        return build_week_nearly_done_step if Definition.week_nearly_done?(base_eligible)
        return build_week_exhausted_step if base_eligible.empty?

        project = resolve_project(plan)
        return build_need_project_step if project.blank?

        data = Cursor.load(@journey)
        data = Cursor.start!(@journey, plan: plan) if data.blank?
        data = ensure_plan_project!(data, plan, project)

        data, healed = sanitize_cursor!(data, plan, project)
        Cursor.save!(@journey, data) if healed

        notice =
          if healed
            I18n.t("strategy.weekly_planner.shell.tree_changed")
          end

        build_step(data, plan: plan, project: project, notice: notice)
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

        base_eligible = Definition.eligible_dates(@user)
        if Definition.week_nearly_done?(base_eligible)
          return AnswerResult.new(ack: nil, next_step: build_week_nearly_done_step, noop: true)
        end
        if base_eligible.empty?
          return AnswerResult.new(ack: nil, next_step: build_week_exhausted_step, noop: true)
        end

        project = resolve_project(plan)
        raise ArgumentError, I18n.t("strategy.weekly_planner.errors.missing_project") if project.blank?

        @journey.with_lock do
          @journey.reload
          data = Cursor.load(@journey)
          data = Cursor.start!(@journey, plan: plan) if data.blank?
          data = ensure_plan_project!(data, plan, project)

          data, healed = sanitize_cursor!(data, plan, project)
          Cursor.save!(@journey, data) if healed

          if data["status"] == "completed"
            return AnswerResult.new(
              ack: ack_for(data),
              next_step: build_step(data, plan: plan, project: project),
              noop: true
            )
          end

          template = Definition.template(data["template_id"])
          key = Cursor.cursor_key(data)
          action = answer_action(value)

          # Idempotent double-submit: only skip when the same continue/days write already landed.
          if data["answered_key"] == key && %w[continue pick_days].include?(action)
            data = heal_answered_write_step(data, template)
            Cursor.save!(@journey, data)
            return AnswerResult.new(
              ack: I18n.t("strategy.weekly_planner.acks.locked"),
              next_step: build_step(data, plan: plan, project: project),
              noop: true
            )
          end

          data = apply_answer!(data, template, value, plan: plan, project: project)
          data["answered_key"] = key if %w[continue pick_days].include?(answer_action(value))
          Cursor.save!(@journey, data)
          AnswerResult.new(
            ack: ack_for(data),
            next_step: build_step(data, plan: plan, project: project),
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

      def sanitize_cursor!(data, plan, project)
        data = data.stringify_keys
        return [ data, false ] if data["status"] == "completed"

        healed = false

        if Cursor.legacy?(data) || (data["plan_id"].present? && data["plan_id"] != plan.id)
          data = Cursor.blank_payload(plan_id: plan.id, project_id: project.id)
          return [ data, true ]
        end

        template_id = data["template_id"].to_s
        items = Array(data["items"])

        if template_id == "pick_days" && items.empty?
          data = data.merge(
            "template_id" => "build_items",
            "item_index" => 0,
            "answered_key" => nil
          )
          healed = true
        elsif template_id == "pick_days"
          index = data["item_index"].to_i
          if index.negative? || index >= items.size
            data = data.merge("item_index" => 0, "answered_key" => nil)
            healed = true
          end
        elsif template_id != "build_items"
          data = Cursor.blank_payload(plan_id: plan.id, project_id: project.id)
          return [ data, true ]
        end

        [ data.merge("project_id" => project.id, "plan_id" => plan.id), healed ]
      end

      def heal_answered_write_step(data, template)
        return data unless Definition.write_kind?(template.kind)
        return data unless data["template_id"] == template.id

        if template.kind == "build_items" && data["items"].present?
          return data.merge("template_id" => "pick_days", "item_index" => 0)
        end

        if template.kind == "pick_days"
          items = Array(data["items"])
          index = data["item_index"].to_i
          current = items[index]
          if current && Array(current["selected_dates"]).any?
            if index + 1 < items.size
              return data.merge("item_index" => index + 1)
            elsif data["status"] != "completed"
              # Already wrote — leave completed if Writer ran; otherwise stay.
              return data
            end
          end
        end

        data
      end

      def answer_action(value)
        if value.is_a?(Hash)
          value.stringify_keys["action"].to_s.presence || "continue"
        else
          "pick_days"
        end
      end

      def apply_answer!(data, template, value, plan:, project:)
        case template.kind
        when "build_items"
          apply_build_items!(data, value, project: project)
        when "pick_days"
          apply_pick_days!(data, value, plan: plan, project: project)
        else
          raise ArgumentError, "unknown write kind: #{template.kind}"
        end
      end

      def apply_build_items!(data, value, project:)
        payload = normalize_build_payload(value)
        items = Array(data["items"]).map(&:dup)

        case payload["action"]
        when "add_item"
          entry = resolve_item_entry(payload["title"], project: project)
          items << entry
          data.merge(
            "items" => items,
            "template_id" => "build_items",
            "item_index" => 0,
            "answered_key" => nil
          )
        when "remove_item"
          index = payload["index"].to_i
          items.delete_at(index) if index >= 0 && index < items.size
          data.merge(
            "items" => items,
            "template_id" => "build_items",
            "item_index" => 0,
            "answered_key" => nil
          )
        when "continue"
          if payload["items"]
            items = payload["items"].map { |row| resolve_item_entry(row, project: project) }
          end
          raise ArgumentError, I18n.t("strategy.weekly_planner.errors.need_items") if items.empty?

          data.merge(
            "items" => items,
            "template_id" => "pick_days",
            "item_index" => 0,
            "answered_key" => nil
          )
        else
          raise ArgumentError, I18n.t("strategy.weekly_planner.shell.bad_answer")
        end
      end

      def normalize_build_payload(value)
        if value.is_a?(Hash) || value.is_a?(ActionController::Parameters)
          h = value.is_a?(ActionController::Parameters) ? value.to_unsafe_h.stringify_keys : value.stringify_keys
          items = h["items"]
          if items.present?
            normalized = Array(items).map { |row| ItemTitle.extract(row) }
            return { "action" => "continue", "items" => normalized }
          end
          {
            "action" => h["action"].to_s.presence || "continue",
            "title" => ItemTitle.extract(h["title"]),
            "index" => h["index"]
          }
        else
          { "action" => "continue", "title" => ItemTitle.extract(value) }
        end
      end

      def resolve_item_entry(raw, project:)
        text = ItemTitle.extract(raw)
        raise ArgumentError, I18n.t("strategy.weekly_planner.errors.blank_title") if text.blank?

        task_id = nil
        title = text

        if (match = text.match(/\Atask:(\d+)\z/))
          task = incomplete_tasks_for(project).find { |t| t.id == match[1].to_i }
          raise ArgumentError, I18n.t("strategy.weekly_planner.errors.bad_source") if task.blank?

          title = task.title
          task_id = task.id
        else
          title = text.delete_prefix("other:").strip
          raise ArgumentError, I18n.t("strategy.weekly_planner.errors.blank_title") if title.blank?
        end

        {
          "title" => title,
          "source_practice_task_id" => task_id,
          "selected_dates" => []
        }
      end

      def apply_pick_days!(data, value, plan:, project:)
        items = Array(data["items"]).map(&:dup)
        index = data["item_index"].to_i
        current = items[index]
        raise ArgumentError, I18n.t("strategy.weekly_planner.errors.need_items") if current.blank?

        dates = parse_day_values(value.is_a?(Hash) ? value.stringify_keys["dates"] : value)
        reserved = Definition.reserved_counts(items, before_index: index)
        eligible = Definition.eligible_dates(@user, reserved: reserved)

        if dates.empty? || dates.any? { |d| !eligible.include?(d) }
          raise ArgumentError, I18n.t("strategy.weekly_planner.errors.bad_dates")
        end

        items[index] = current.merge("selected_dates" => dates.map(&:iso8601))
        updated = data.merge(
          "items" => items,
          "plan_id" => plan.id,
          "project_id" => project.id
        )

        if index + 1 < items.size
          next_reserved = Definition.reserved_counts(items, before_index: index + 1)
          next_eligible = Definition.eligible_dates(@user, reserved: next_reserved)
          if next_eligible.empty?
            # Remaining items cannot be placed — write what we have.
            return Writer.call(user: @user, journey: @journey, cursor: updated.merge(
              "items" => items.first(index + 1)
            ))
          end

          return updated.merge(
            "template_id" => "pick_days",
            "item_index" => index + 1
          )
        end

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

      def eligible_for_data(data)
        items = Array(data["items"])
        index = data["item_index"].to_i
        reserved =
          if data["template_id"].to_s == "pick_days"
            Definition.reserved_counts(items, before_index: index)
          else
            {}
          end
        Definition.eligible_dates(@user, reserved: reserved)
      end

      def build_step(data, plan:, project:, notice: nil)
        data = data.stringify_keys
        if data["status"] == "completed"
          titles = Array(data["items"]).map { |i| ItemTitle.extract(i["title"]) }.compact_blank
          return Step.new(
            template_id: data["template_id"],
            kind: "completed",
            question: nil,
            status: "completed",
            notice: notice,
            title: titles.join(", "),
            items: data["items"],
            item_index: data["item_index"],
            item_progress: nil,
            suggestions: nil,
            already_this_week: nil,
            eligible_dates: Definition.eligible_dates(@user),
            weekday_hint: nil,
            framing_line: nil,
            cap_note: nil,
            created_count: data["created_count"],
            skipped: data["skipped"]
          )
        end

        template = Definition.template(data["template_id"])
        eligible = eligible_for_data(data)
        items = Array(data["items"])
        index = data["item_index"].to_i
        current = items[index]

        if template.kind == "pick_days" && eligible.empty?
          return build_week_exhausted_step
        end

        progress =
          if template.kind == "pick_days" && items.size.positive?
            I18n.t(
              "strategy.weekly_planner.shell.item_progress",
              n: index + 1,
              total: items.size
            )
          end

        Step.new(
          template_id: template.id,
          kind: template.kind,
          question: question_for(template, current),
          status: data["status"],
          notice: notice,
          title: current && ItemTitle.extract(current["title"]),
          items: items,
          item_index: index,
          item_progress: progress,
          suggestions: suggestions_for(template, project, items),
          already_this_week: already_this_week_for(template),
          eligible_dates: eligible,
          weekday_hint: weekday_hint_for(template),
          framing_line: framing_for(template),
          cap_note: cap_note_for(template, eligible),
          created_count: nil,
          skipped: []
        )
      end

      def already_this_week_for(template)
        return nil unless template.kind == "build_items"

        range = Date.current.beginning_of_week..Date.current.end_of_week
        counts = @user.daily_todos
          .where(scheduled_on: range)
          .group(:title)
          .count("DISTINCT scheduled_on")

        counts.filter_map do |title, days|
          label = ItemTitle.extract(title).presence
          next if label.blank?

          { title: label, days: days.to_i }
        end.sort_by { |row| [ -row[:days], row[:title].downcase ] }
      end

      def question_for(template, current)
        if template.kind == "pick_days" && current
          I18n.t(template.question_key, title: ItemTitle.extract(current["title"]))
        else
          I18n.t(template.question_key)
        end
      end

      def suggestions_for(template, project, items)
        return nil unless template.kind == "build_items"

        taken = items.map { |i| ItemTitle.extract(i["title"]).downcase }
        incomplete_tasks_for(project).filter_map do |task|
          next if taken.include?(task.title.to_s.downcase)

          { value: "task:#{task.id}", label: task.title }
        end
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
        return nil unless template.kind == "build_items"

        I18n.t("strategy.weekly_planner.shell.framing")
      end

      def cap_note_for(template, eligible)
        return nil unless template.kind == "pick_days"
        return nil unless eligible.size.positive?

        week_days = (Date.current..Date.current.end_of_week).count
        return nil unless eligible.size < week_days

        I18n.t("strategy.weekly_planner.shell.cap_note", count: eligible.size)
      end

      def build_week_nearly_done_step
        terminal_step(
          kind: "week_nearly_done",
          question: I18n.t("strategy.weekly_planner.shell.week_nearly_done_title"),
          notice: I18n.t("strategy.weekly_planner.shell.week_nearly_done_body")
        )
      end

      def build_week_exhausted_step
        terminal_step(
          kind: "week_exhausted",
          question: I18n.t("strategy.weekly_planner.shell.week_exhausted_title"),
          notice: I18n.t("strategy.weekly_planner.shell.week_exhausted_body")
        )
      end

      def build_need_project_step
        terminal_step(
          kind: "week_exhausted",
          question: I18n.t("strategy.weekly_planner.shell.need_project_title"),
          notice: I18n.t("strategy.weekly_planner.shell.need_project_body")
        )
      end

      def terminal_step(kind:, question:, notice:)
        Step.new(
          template_id: nil,
          kind: kind,
          question: question,
          status: kind,
          notice: notice,
          title: nil,
          items: [],
          item_index: 0,
          item_progress: nil,
          suggestions: nil,
          already_this_week: nil,
          eligible_dates: [],
          weekday_hint: nil,
          framing_line: nil,
          cap_note: nil,
          created_count: nil,
          skipped: []
        )
      end

      def ack_for(data)
        if data["status"] == "completed"
          done_flash_for(data)
        elsif data["template_id"] == "build_items"
          nil
        else
          I18n.t("strategy.weekly_planner.acks.locked")
        end
      end

      def done_flash_for(data)
        items = Array(data["items"])
        things = items.size
        slots = data["created_count"].to_i
        things_label = I18n.t("strategy.weekly_planner.shell.done_things", count: things)
        slots_label = I18n.t("strategy.weekly_planner.shell.done_slots", count: slots)
        base = I18n.t(
          "strategy.weekly_planner.shell.done_flash",
          things: things_label,
          slots: slots_label
        )
        skipped = Array(data["skipped"])
        return base if skipped.empty?

        skip_bits = skipped.map do |row|
          date = begin
            Date.iso8601(row["date"].to_s)
          rescue ArgumentError, TypeError
            nil
          end
          day = date ? I18n.l(date, format: "%A") : row["date"]
          I18n.t(
            "strategy.weekly_planner.shell.skip_one",
            day: day,
            title: ItemTitle.extract(row["title"])
          )
        end
        "#{base} #{skip_bits.join(' ')}"
      end
    end
  end
end
