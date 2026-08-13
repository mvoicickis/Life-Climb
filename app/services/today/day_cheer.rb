# frozen_string_literal: true

module Today
  # Escalating cheer line for the Today hero from DayPercent (display only).
  class DayCheer
    Result = Struct.new(:band, :css, keyword_init: true)

    def self.call(percent:)
      new(percent: percent).call
    end

    def initialize(percent:)
      @percent = percent.nil? ? nil : percent.to_i
    end

    def call
      band, css = classify
      Result.new(band: band, css: css)
    end

    def message
      result = call
      over = [ (@percent || 0) - 100, 0 ].max
      I18n.t("dash.hero.cheer.#{result.band}", over: over)
    end

    private

    def classify
      p = @percent
      return [ :idle, "idle" ] if p.nil? || p <= 0
      return [ :moving, "up" ] if p < 25
      return [ :good_ground, "up" ] if p < 60
      return [ :close, "up" ] if p < 100
      return [ :met, "up" ] if p == 100

      [ :over, "over" ]
    end
  end
end
