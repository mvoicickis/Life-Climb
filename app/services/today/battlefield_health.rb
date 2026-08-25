# frozen_string_literal: true

module Today
  # Mockup TodayV2 "Health" — share of today's battles already won.
  class BattlefieldHealth
    Result = Struct.new(
      :hp,
      :done_count,
      :total_count,
      :open_count,
      :band,
      :risk_icon,
      :risk_note,
      :result_title,
      keyword_init: true
    ) do
      def safe?
        band == :safe
      end

      def warn?
        band == :warn
      end

      def danger?
        band == :danger
      end

      def all_clear?
        total_count.positive? && open_count.zero?
      end

      def empty?
        total_count.zero?
      end
    end

    def self.call(open_count:, total_count:)
      new(open_count:, total_count:).call
    end

    def initialize(open_count:, total_count:)
      @open_count = open_count.to_i
      @total_count = total_count.to_i
      @done_count = [ @total_count - @open_count, 0 ].max
    end

    def call
      hp = @total_count.zero? ? 100 : ((@done_count.to_f / @total_count) * 100).round
      band = hp >= 70 ? :safe : hp >= 35 ? :warn : :danger

      Result.new(
        hp: hp,
        done_count: @done_count,
        total_count: @total_count,
        open_count: @open_count,
        band: band,
        risk_icon: @open_count.zero? ? "✓" : "⚠",
        risk_note: risk_note_for(@open_count),
        result_title: result_title_for(hp)
      )
    end

    private

    def risk_note_for(open_count)
      if open_count.zero?
        I18n.t("dash.battlefield.risk_cleared")
      else
        I18n.t("dash.battlefield.risk_open", count: open_count)
      end
    end

    def result_title_for(hp)
      if hp >= 70
        I18n.t("dash.battlefield.recap_crushed")
      elsif hp >= 35
        I18n.t("dash.battlefield.recap_survived")
      else
        I18n.t("dash.battlefield.recap_rough")
      end
    end
  end
end
