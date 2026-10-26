# frozen_string_literal: true

module Notifications
  module NudgeBody
    module_function

    def build(user:, date:, fallback:)
      battle = OpenBattleTitle.for(user: user, on: date)
      rest = battle.presence || fallback
      commitment = Today::StreakCommitment.peek(user, date: date)

      if commitment
        I18n.t(
          "notifications.push.day_of_commitment",
          n: commitment[:n],
          m: commitment[:target],
          rest: rest
        )
      elsif battle.present?
        I18n.t("notifications.push.today_battle", title: battle)
      else
        fallback
      end
    end
  end
end
