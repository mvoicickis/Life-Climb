# frozen_string_literal: true

module Notifications
  # Morning nudge copy + destination: personalised Mountain camp or generic Today.
  class MorningNudgeBody
    CAMP_LIMIT = 24
    BATTLE_LIMIT = 36
    BODY_LIMIT = 120

    Result = Struct.new(:body, :url, :battle_id, keyword_init: true)

    def self.for(user:, locale: I18n.locale)
      new(user:, locale:).call
    end

    def initialize(user:, locale:)
      @user = user
      @locale = locale
    end

    def call
      focus = MountainTrail::CurrentFocus.for(user: @user)
      if focus.camp.present? && focus.battle.present?
        personal(focus)
      else
        generic
      end
    end

    private

    def generic
      Result.new(
        body: PhraseBank.morning_nudge(locale: @locale),
        url: "/dashboard",
        battle_id: nil
      )
    end

    def personal(focus)
      camp_title = focus.camp.title.to_s.truncate(CAMP_LIMIT)
      battle_title = focus.battle.title.to_s.truncate(BATTLE_LIMIT)
      phrase = I18n.with_locale(@locale) do
        I18n.t(
          "notifications.morning_nudge_personal.body",
          camp: camp_title,
          battle: battle_title
        )
      end
      body = "#{PhraseBank::PREFIXES["morning_nudge"]}#{phrase}".truncate(BODY_LIMIT)
      url = helpers.life_journey_path(
        focus.journey,
        goal_id: focus.goal.id,
        plan_id: focus.plan.id,
        focus_id: focus.camp.id,
        open_camp: 1
      )

      Result.new(body: body, url: url, battle_id: focus.battle.id)
    end

    def helpers
      Rails.application.routes.url_helpers
    end
  end
end
