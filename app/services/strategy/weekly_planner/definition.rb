# frozen_string_literal: true

module Strategy
  module WeeklyPlanner
    # Declarative templates for the weekly sitting planner.
    # pick_source → pick_count → pick_days → Writer commit.
    class Definition
      Template = Data.define(:id, :kind, :question_key)

      WRITE_KINDS = %w[pick_source pick_count pick_days].freeze

      TEMPLATES = [
        Template.new(
          id: "pick_source",
          kind: "pick_source",
          question_key: "strategy.weekly_planner.questions.pick_source"
        ),
        Template.new(
          id: "pick_count",
          kind: "pick_count",
          question_key: "strategy.weekly_planner.questions.pick_count"
        ),
        Template.new(
          id: "pick_days",
          kind: "pick_days",
          question_key: "strategy.weekly_planner.questions.pick_days"
        )
      ].freeze

      BY_ID = TEMPLATES.index_by(&:id).freeze

      def self.template(id)
        BY_ID.fetch(id.to_s)
      rescue KeyError
        raise ArgumentError, "unknown weekly planner template: #{id}"
      end

      def self.write_kind?(kind)
        WRITE_KINDS.include?(kind.to_s)
      end

      def self.next_after_write(template_id)
        case template_id.to_s
        when "pick_source" then "pick_count"
        when "pick_count" then "pick_days"
        when "pick_days" then nil
        else
          raise ArgumentError, "no write-advance for #{template_id}"
        end
      end

      # Remaining days this week that still have room under MAX_DAILY_TODOS.
      def self.eligible_dates(user, on: Date.current)
        (on..on.end_of_week).select do |date|
          user.daily_todos.for_day(date).count < GameRules::MAX_DAILY_TODOS
        end
      end

      def self.max_sittings(journey, eligible)
        [
          journey.commitment_battle_count.to_i,
          eligible.size
        ].min
      end

      # Sunday (last day of week) with < 2 open dates: calm exit, not a dead-end.
      def self.week_nearly_done?(eligible, on: Date.current)
        on == on.end_of_week && eligible.size < 2
      end
    end
  end
end
