# frozen_string_literal: true

module Notifications
  module NudgeBody
    module_function

    def build(user:, date:, fallback:)
      battle = OpenBattleTitle.for(user: user, on: date)
      if battle.present?
        I18n.t("notifications.push.today_battle", title: battle)
      else
        fallback
      end
    end
  end
end
