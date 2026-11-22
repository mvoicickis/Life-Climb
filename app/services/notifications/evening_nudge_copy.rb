# frozen_string_literal: true

module Notifications
  # Title matches morning push; evening body or today's battle.
  class EveningNudgeCopy
    Result = Struct.new(:title, :body, :url, keyword_init: true)

    def self.for(user:, date:, locale: I18n.locale, open_battle: nil)
      new(user: user, date: date, locale: locale, open_battle: open_battle).call
    end

    def initialize(user:, date:, locale: I18n.locale, open_battle: nil)
      @user = user
      @date = date
      @locale = locale
      @open_battle = open_battle
    end

    def call
      battle = resolved_open_battle
      morning = MorningNudgeCopy.for(user: @user, date: @date, locale: @locale, open_battle: battle)
      I18n.with_locale(@locale) do
        Result.new(
          title: morning.title,
          body: NudgeBody.build(
            user: @user,
            date: @date,
            fallback: NudgeFallbackLine.for(user: @user, date: @date, kind: :evening, locale: @locale),
            open_battle: battle
          ),
          url: NudgeDashboardUrl.for(open_battle: battle)
        )
      end
    end

    def resolved_open_battle
      return @open_battle if @open_battle

      battle = OpenBattle.for(user: @user, on: @date)
      EnsureFocusForOpenBattle.call(user: @user, open_battle: battle)
      battle
    end
  end
end
