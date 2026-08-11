# frozen_string_literal: true

module Patterns
  module Detectors
    # Best vs worst weekday success rate (by scheduled_on), with a minimum gap.
    class WeekdayGap
      def self.call(user:, on: Date.current)
        new(user: user, on: on).call
      end

      def initialize(user:, on: Date.current)
        @user = user
        @on = on
      end

      def call
        summary = Patterns::BattleStats.summary(@user, on: @on)
        return nil if summary[:days_active] < Patterns::BattleStats::MIN_DAYS_ACTIVE
        return nil if summary[:scheduled] < Patterns::BattleStats::MIN_SCHEDULED

        rates = Patterns::BattleStats.weekday_rates(@user, on: @on)
        return nil if rates.size < 2

        best = rates.max_by { |row| [ row[:rate], row[:scheduled_n] ] }
        worst = rates.min_by { |row| [ row[:rate], -row[:scheduled_n] ] }
        return nil if best[:wday] == worst[:wday]

        gap = best[:rate] - worst[:rate]
        return nil if gap < Patterns::BattleStats::MIN_WEEKDAY_GAP

        Patterns::Finding.new(
          key: :weekday_gap,
          cta_variant: :plan_weekday,
          data: {
            best_wday: best[:wday],
            best_rate: best[:rate],
            best_scheduled_n: best[:scheduled_n],
            worst_wday: worst[:wday],
            worst_rate: worst[:rate],
            worst_scheduled_n: worst[:scheduled_n],
            gap: gap
          }
        )
      end
    end
  end
end
