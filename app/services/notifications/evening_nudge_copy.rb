# frozen_string_literal: true

module Notifications
  # Title matches morning push; evening body or today's battle.
  class EveningNudgeCopy
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
      morning = MorningNudgeCopy.for(user: @user, date: @date, locale: @locale)
      I18n.with_locale(@locale) do
        Result.new(
          title: morning.title,
          body: NudgeBody.build(
            user: @user,
            date: @date,
            fallback: I18n.t("notifications.evening_push.body")
          )
        )
      end
    end
  end
end
