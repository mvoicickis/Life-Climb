# frozen_string_literal: true

module Notifications
  # Title/body for the daily morning push — incomplete Today battle or plan prompt.
  class MorningNudgeCopy
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
      incomplete = first_incomplete_todo
      if incomplete
        battle_copy(incomplete.title)
      else
        plan_copy
      end
    end

    private

    def first_incomplete_todo
      @user.daily_todos.for_day(@date).ordered.incomplete.first
    end

    def battle_copy(title)
      I18n.with_locale(@locale) do
        Result.new(
          title: I18n.t("notifications.morning_push.battle_title"),
          body: I18n.t("notifications.morning_push.battle_body", title: title)
        )
      end
    end

    def plan_copy
      I18n.with_locale(@locale) do
        Result.new(
          title: I18n.t("notifications.morning_push.plan_title"),
          body: I18n.t("notifications.morning_push.plan_body")
        )
      end
    end
  end
end
