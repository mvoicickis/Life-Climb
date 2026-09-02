# frozen_string_literal: true

module Analytics
  # Emit first_battle_won once when a user completes their first DailyTodo battle.
  class TrackFirstBattleWon
    EVENT = "first_battle_won"

    def self.call(user:)
      new(user:).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      return if @user.user_events.named(EVENT).exists?
      return unless @user.battle_won_once?

      Analytics::Track.call(user: @user, name: EVENT)
    end
  end
end
