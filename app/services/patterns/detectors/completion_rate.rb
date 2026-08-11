# frozen_string_literal: true

module Patterns
  module Detectors
    # 30-day Battle completion rate from scheduled daily_todos.
    class CompletionRate
      HIGH_MIN = 65
      NEUTRAL_MIN = 40

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

        band = band_for(summary[:rate])
        Patterns::Finding.new(
          key: :completion_rate_30d,
          cta_variant: band,
          data: {
            rate: summary[:rate],
            completed: summary[:completed],
            scheduled: summary[:scheduled],
            days_active: summary[:days_active],
            band: band.to_s
          }
        )
      end

      private

      def band_for(rate)
        if rate >= HIGH_MIN
          :high
        elsif rate >= NEUTRAL_MIN
          :neutral
        else
          :low
        end
      end
    end
  end
end
