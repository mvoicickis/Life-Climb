# frozen_string_literal: true

module Notifications
  # Title/body for the daily morning push — focused goal title and rotating fallback line.
  class MorningNudgeCopy
    Result = Struct.new(:title, :body, :url, keyword_init: true)

    def self.for(user:, date:, locale: I18n.locale, open_battle: nil)
      new(user: user, date: date, locale: locale, open_battle: open_battle).call
    end

    def self.focused_goal_name_for(user:)
      new(user: user, date: user.local_today).focused_goal_name
    end

    def initialize(user:, date:, locale: I18n.locale, open_battle: nil)
      @user = user
      @date = date
      @locale = locale
      @open_battle = open_battle
    end

    def call
      I18n.with_locale(@locale) do
        battle = resolved_open_battle
        Result.new(
          title: title,
          body: body(battle),
          url: NudgeDashboardUrl.for(open_battle: battle)
        )
      end
    end

    def focused_goal_name
      pair = Goals::Current.call(user: @user)
      journey = pair.journey
      return nil if journey.blank?

      strategy_goal = pair.goal
      raw = strategy_goal&.title.presence || journey.title.presence
      return nil if raw.blank?

      fallback = I18n.t("dash.active_goal_fallback")
      return nil if raw == fallback

      raw
    end

    private

    def title
      raw = focused_goal_name
      if raw.present?
        PushGoalTitle.truncate(raw, limit: 40)
      else
        I18n.t("notifications.morning_push.plan_title")
      end
    end

    def body(open_battle)
      fallback = NudgeFallbackLine.for(user: @user, date: @date, kind: :morning, locale: @locale)
      NudgeBody.build(user: @user, date: @date, fallback: fallback, open_battle: open_battle)
    end

    def resolved_open_battle
      return @open_battle if @open_battle

      battle = OpenBattle.for(user: @user, on: @date)
      EnsureFocusForOpenBattle.call(user: @user, open_battle: battle)
      battle
    end
  end
end
