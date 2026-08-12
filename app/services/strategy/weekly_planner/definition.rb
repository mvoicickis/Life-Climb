# frozen_string_literal: true

module Strategy
  module WeeklyPlanner
    # Declarative templates for the weekly sitting planner.
    # build_items → pick_days (per item) → Writer commit.
    class Definition
      Template = Data.define(:id, :kind, :question_key)

      WRITE_KINDS = %w[build_items pick_days].freeze

      TEMPLATES = [
        Template.new(
          id: "build_items",
          kind: "build_items",
          question_key: "strategy.weekly_planner.questions.build_items"
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
        when "build_items" then "pick_days"
        when "pick_days" then nil
        else
          raise ArgumentError, "no write-advance for #{template_id}"
        end
      end

      # Remaining days this week with room under MAX_DAILY_TODOS.
      # +reserved+ is a Hash{Date => Integer} of seats already claimed by
      # earlier items in the current planner cursor (items 0..N-1).
      def self.eligible_dates(user, on: Date.current, reserved: {})
        reserved = reserved.transform_keys { |k| k.is_a?(Date) ? k : Date.iso8601(k.to_s) }
        (on..on.end_of_week).select do |date|
          used = user.daily_todos.for_day(date).count + reserved.fetch(date, 0)
          used < GameRules::MAX_DAILY_TODOS
        end
      rescue ArgumentError, TypeError
        (on..on.end_of_week).select do |date|
          user.daily_todos.for_day(date).count < GameRules::MAX_DAILY_TODOS
        end
      end

      # Seats claimed by items before +before_index+ in the cursor.
      def self.reserved_counts(items, before_index:)
        counts = Hash.new(0)
        Array(items).first([ before_index.to_i, 0 ].max).each do |item|
          Array(item["selected_dates"]).each do |raw|
            date = Date.iso8601(raw.to_s)
            counts[date] += 1
          rescue ArgumentError, TypeError
            next
          end
        end
        counts
      end

      def self.max_sittings(_journey, eligible)
        eligible.size
      end

      # Sunday (last day of week) with < 2 open dates: calm exit, not a dead-end.
      def self.week_nearly_done?(eligible, on: Date.current)
        on == on.end_of_week && eligible.size < 2
      end
    end
  end
end
