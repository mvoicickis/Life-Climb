# frozen_string_literal: true

module Strategy
  module CompanionGuide
    # Companion-voice acknowledgments between guide steps.
    # Same sample style as Strategy::NextAction::Copy / Notifications::PhraseBank.
    class Copy
      INDEXES = (0..5).freeze
      PREFIX = "✅ "

      def self.ack(locale: I18n.locale)
        I18n.with_locale(locale) do
          phrase = INDEXES.map { |i| I18n.t("strategy.companion_guide.acks.#{i}") }.sample
          "#{PREFIX}#{phrase}"
        end
      end

      def self.phrases(locale: I18n.locale)
        I18n.with_locale(locale) do
          INDEXES.map { |i| I18n.t("strategy.companion_guide.acks.#{i}") }
        end
      end
    end
  end
end
