# frozen_string_literal: true

module Notifications
  module NudgeBody
    module_function

    def build(user:, date:, fallback:, open_battle: nil)
      open_battle ||= OpenBattle.for(user: user, on: date)
      battle_title = open_battle&.title
      rest = battle_title.presence || fallback
      commitment = Today::StreakCommitment.peek(user, date: date)

      if commitment
        I18n.t(
          "notifications.push.day_of_commitment",
          n: commitment[:n],
          m: commitment[:target],
          rest: rest
        )
      elsif battle_title.present?
        I18n.t("notifications.push.today_battle", title: battle_title)
      else
        fallback
      end
    end
  end
end
