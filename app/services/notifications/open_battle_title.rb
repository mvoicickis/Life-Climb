# frozen_string_literal: true

module Notifications
  # Next open battle title for push body — read-only.
  class OpenBattleTitle
    def self.for(user:, on:)
      OpenBattle.for(user: user, on: on)&.title
    end
  end
end
