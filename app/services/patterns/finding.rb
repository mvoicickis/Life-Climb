# frozen_string_literal: true

module Patterns
  # Runtime finding: snapshot stores key + data + cta_variant only;
  # observation / CTA labels render via I18n at read time.
  class Finding
    attr_reader :key, :data, :cta_variant

    def initialize(key:, data:, cta_variant:)
      @key = key.to_sym
      @data = (data || {}).deep_symbolize_keys
      @cta_variant = cta_variant.to_sym
    end

    def observation
      case key
      when :completion_rate_30d
        I18n.t(
          "progress.patterns.completion_rate.#{cta_variant}",
          rate: data[:rate],
          completed: data[:completed],
          scheduled: data[:scheduled]
        )
      when :weekday_gap
        I18n.t(
          "progress.patterns.weekday_gap.observation",
          worst: day_name(data[:worst_wday]),
          worst_rate: data[:worst_rate],
          best: day_name(data[:best_wday]),
          best_rate: data[:best_rate]
        )
      else
        ""
      end
    end

    def action_label
      case cta_variant
      when :high
        I18n.t("progress.patterns.cta.open_mountain")
      when :neutral, :low
        I18n.t("progress.patterns.cta.open_today")
      when :plan_weekday
        I18n.t("progress.patterns.cta.plan_day", day: day_name(data[:worst_wday]))
      end
    end

    def action_path(user:)
      helpers = Rails.application.routes.url_helpers
      case cta_variant
      when :high
        journey = user.primary_focused_journey
        journey ? helpers.life_journey_path(journey) : helpers.dashboard_path
      else
        helpers.dashboard_path
      end
    end

    def to_snapshot_h
      {
        "key" => key.to_s,
        "cta_variant" => cta_variant.to_s,
        "data" => data.deep_stringify_keys
      }
    end

    def self.from_snapshot_h(hash)
      h = hash.stringify_keys
      new(
        key: h.fetch("key"),
        cta_variant: h.fetch("cta_variant"),
        data: h.fetch("data")
      )
    end

    private

    def day_name(wday)
      I18n.t("date.day_names")[wday.to_i]
    end
  end
end
