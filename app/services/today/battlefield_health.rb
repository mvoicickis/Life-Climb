# frozen_string_literal: true

module Today
  # Today V2 progress — share of today's battles already won (count-up, no guilt bands).
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

      def neutral?
        band == :neutral
      end

      def all_clear?
        total_count.positive? && open_count.zero?
      end

      def empty?
        total_count.zero?
      end
    end

    def self.call(open_count:, total_count:, habits: [])
      new(open_count:, total_count:, habits:).call
    end

    def initialize(open_count:, total_count:, habits: [])
      @open_count = open_count.to_i
      @total_count = total_count.to_i
      @habits = Array(habits)
      @done_count = [ @total_count - @open_count, 0 ].max
    end

    def call
      return empty_result if @total_count.zero?

      hp = ((@done_count.to_f / @total_count) * 100).round

      Result.new(
        hp: hp,
        done_count: @done_count,
        total_count: @total_count,
        open_count: @open_count,
        band: :neutral,
        risk_icon: @open_count.zero? ? "✓" : "",
        risk_note: risk_note_for(@open_count),
        result_title: result_title_for(hp)
      )
    end

    private

    def empty_result
      Result.new(
        hp: 0,
        done_count: 0,
        total_count: 0,
        open_count: @open_count,
        band: :neutral,
        risk_icon: "",
        risk_note: I18n.t("dash.battlefield.risk_empty"),
        result_title: I18n.t("dash.battlefield.recap_empty")
      )
    end

    def risk_note_for(open_count)
      if open_count.positive?
        I18n.t("dash.battlefield.risk_open", count: open_count)
      elsif basics_remaining?
        remaining = @habits.count { |habit| !habit.survived_today? }
        I18n.t("dash.battlefield.risk_basics_left", count: remaining)
      else
        I18n.t("dash.battlefield.risk_cleared")
      end
    end

    def basics_remaining?
      @habits.present? && @habits.any? { |habit| !habit.survived_today? }
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
