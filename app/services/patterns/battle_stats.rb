# frozen_string_literal: true

module Patterns
  # Shared scheduled_on-based battle aggregates for pattern detectors.
  # Never use completed_at's calendar date for rate math.
  module BattleStats
    WINDOW_DAYS = 30
    MIN_DAYS_ACTIVE = 7
    MIN_SCHEDULED = 10
    MIN_PER_WEEKDAY = 3
    MIN_WEEKDAY_GAP = 30

    module_function

    def window(on: Date.current)
      (on - (WINDOW_DAYS - 1))..on
    end

    def todos_scope(user, on: Date.current)
      user.daily_todos.where(scheduled_on: window(on: on))
    end

    # days_active = distinct scheduled_on dates with ≥1 todo (not row count).
    def summary(user, on: Date.current)
      scope = todos_scope(user, on: on)
      scheduled = scope.count
      completed = scope.where.not(completed_at: nil).count
      days_active = scope.distinct.count(:scheduled_on)
      rate = scheduled.zero? ? 0 : ((completed.to_f / scheduled) * 100).round

      {
        scheduled: scheduled,
        completed: completed,
        days_active: days_active,
        rate: rate
      }
    end

    # Returns array of { wday:, scheduled_n:, completed_n:, rate: } for weekdays
    # that meet MIN_PER_WEEKDAY. wday matches Date#wday (0 = Sunday).
    def weekday_rates(user, on: Date.current)
      rows = todos_scope(user, on: on).pluck(:scheduled_on, :completed_at)
      by_wday = Hash.new { |h, k| h[k] = { scheduled_n: 0, completed_n: 0 } }

      rows.each do |scheduled_on, completed_at|
        bucket = by_wday[scheduled_on.wday]
        bucket[:scheduled_n] += 1
        bucket[:completed_n] += 1 if completed_at.present?
      end

      by_wday.filter_map do |wday, stats|
        next if stats[:scheduled_n] < MIN_PER_WEEKDAY

        rate = ((stats[:completed_n].to_f / stats[:scheduled_n]) * 100).round
        {
          wday: wday,
          scheduled_n: stats[:scheduled_n],
          completed_n: stats[:completed_n],
          rate: rate
        }
      end
    end
  end
end
