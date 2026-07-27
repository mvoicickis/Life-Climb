# frozen_string_literal: true

module Developer
  # Full New Player Experience restart for the developer account.
  # Wipes Strategy / journey data so the app feels brand new.
  # Never deletes the User account, Action Points, or habits.
  class RestartNewPlayerExperience
    def self.call(user:)
      new(user:).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      ActiveRecord::Base.transaction do
        @user.daily_todos.delete_all
        @user.strategy_goals.destroy_all
        @user.life_journeys.destroy_all
        @user.strategy_point_ledgers.delete_all

        shown = Array(@user.support_milestones_shown).map(&:to_s)
        shown.delete(User::ADVENTURE_GUIDE_KEY)

        @user.update!(
          onboarding_completed_at: nil,
          planning_version: 2,
          strategy_points: 0,
          support_milestones_shown: shown
        )
      end

      @user
    end
  end
end
