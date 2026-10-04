# frozen_string_literal: true

module Notifications
  # Title/body for the daily morning push — focused goal title and weekday line.
  class MorningNudgeCopy
    WEEKDAY_KEYS = %w[sun mon tue wed thu fri sat].freeze

    Result = Struct.new(:title, :body, keyword_init: true)

    def self.for(user:, date:, locale: I18n.locale)
      new(user: user, date: date, locale: locale).call
    end

    def initialize(user:, date:, locale: I18n.locale)
      @user = user
      @date = date
      @locale = locale
    end

    def call
      I18n.with_locale(@locale) do
        Result.new(title: title, body: body)
      end
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

    def body
      key = WEEKDAY_KEYS[@date.wday]
      fallback = I18n.t("notifications.morning_push.weekday_#{key}")
      NudgeBody.build(user: @user, date: @date, fallback: fallback)
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
  end
end
