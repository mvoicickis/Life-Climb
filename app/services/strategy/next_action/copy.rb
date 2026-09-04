# frozen_string_literal: true

module Strategy
  class NextAction
    # Companion-voice headlines for the NextAction banner. Separate from
    # Notifications::PhraseBank (different trigger context) but same sample style.
    class Copy
      KEYS = %i[
        plan_route
        set_today
        complete_battle
        day_won
        battle_overdue
        streak_at_risk
        project_unlocked
        quest_stalled
      ].freeze

      PREFIXES = {
        plan_route: "🧭 ",
        set_today: "📍 ",
        complete_battle: "⚔️ ",
        day_won: "🏁 ",
        battle_overdue: "⚠️ ",
        streak_at_risk: "🔥 ",
        project_unlocked: "✨ ",
        quest_stalled: "🌑 "
      }.freeze

      def self.phrases_for(key:, locale: I18n.locale)
        key = key.to_sym
        raise ArgumentError, "unknown next_action key: #{key}" unless KEYS.include?(key)

        I18n.with_locale(locale) do
          Array(I18n.t("strategy.next_action.#{key}.titles"))
        end
      end

      def self.headline_for(key:, title: nil, count: nil, locale: I18n.locale)
        key = key.to_sym
        phrase = phrases_for(key:, locale:).sample.to_s
        vars = {}
        vars[:title] = title.to_s if phrase.include?("%{title}")
        vars[:count] = count if phrase.include?("%{count}") && !count.nil?
        phrase = I18n.interpolate(phrase, **vars) if vars.any?
        "#{PREFIXES.fetch(key)}#{phrase}"
      end
    end
  end
end
