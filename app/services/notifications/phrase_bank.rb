# frozen_string_literal: true

module Notifications
  # Random companion copy for push bodies. Emoji prefixes are added at render time.
  class PhraseBank
    TRIGGERS = %w[win stuck].freeze
    INDEXES = (0..5).freeze
    DEFAULT_CATEGORY = "other"
    PREFIXES = {
      "win" => "🏔️ ",
      "stuck" => "👋 ",
      "morning_nudge" => "☀️ "
    }.freeze

    def self.body_for(kind:, category:, locale: I18n.locale)
      new(kind: kind, category: category, locale: locale).body
    end

    def self.morning_nudge(locale: I18n.locale)
      I18n.with_locale(locale) do
        phrase = INDEXES.map { |i| I18n.t("notifications.morning_nudge.#{i}") }.sample
        "#{PREFIXES["morning_nudge"]}#{phrase}"
      end
    end

    def self.normalize_category(category)
      Onboarding::Categories.valid_id?(category) ? category.to_s : DEFAULT_CATEGORY
    end

    def self.phrases_for(kind:, category:, locale: I18n.locale)
      cat = normalize_category(category)
      I18n.with_locale(locale) do
        INDEXES.map { |i| I18n.t("notifications.#{kind}.#{cat}.#{i}") }
      end
    end

    def initialize(kind:, category:, locale: I18n.locale)
      @kind = kind.to_s
      @category = self.class.normalize_category(category)
      @locale = locale
    end

    def body
      raise ArgumentError, "unknown kind: #{@kind}" unless TRIGGERS.include?(@kind)

      phrase = self.class.phrases_for(kind: @kind, category: @category, locale: @locale).sample
      "#{PREFIXES[@kind]}#{phrase}"
    end
  end
end
