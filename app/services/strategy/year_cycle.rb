# frozen_string_literal: true

module Strategy
  # Soft finish line for a climb. New goals default to one year from today;
  # older Dec 29 helpers remain for legacy references/tests.
  class YearCycle
    MONTH_DAY = [ 12, 29 ].freeze

    def self.default_goal_due(today = Date.current)
      today + 1.year
    end

    def self.target_dec29(today = Date.current)
      candidate = Date.new(today.year, *MONTH_DAY)
      today <= candidate ? candidate : Date.new(today.year + 1, *MONTH_DAY)
    end

    def self.dec29?(date)
      date.present? && date.month == 12 && date.day == 29
    end

    # Remaining calendar months from today through the month of target.
    def self.remaining_month_slots(today: Date.current, target: default_goal_due(today))
      cursor = Date.new(today.year, today.month, 1)
      last = Date.new(target.year, target.month, 1)
      slots = []

      while cursor <= last
        due =
          if cursor.year == target.year && cursor.month == target.month
            target
          else
            cursor.end_of_month
          end
        slots << {
          year: cursor.year,
          month: cursor.month,
          due_on: due,
          label: I18n.l(cursor, format: "%B %Y")
        }
        cursor = cursor.next_month
      end

      slots
    end
  end
end
