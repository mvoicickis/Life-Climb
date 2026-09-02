# frozen_string_literal: true

module Developer
  # Full New Player Experience restart for the developer account.
  # Wipes Strategy / journey data and habits (plus their logs/check-offs),
  # clears push / install-offer / tour state, and clears the companion so the
  # climber re-picks on the next run. Never deletes the User account or Action Points.
  class RestartNewPlayerExperience
    def self.call(user:)
      new(user:).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      ActiveRecord::Base.transaction do
        # Quantity logs FK to daily_todos — must go first (delete_all skips nullify callbacks).
        @user.strategy_quantity_logs.delete_all
        @user.daily_todos.delete_all
        StrategyGoal.with_holding_destroy { @user.strategy_goals.destroy_all }
        @user.life_journeys.destroy_all
        # Journeys first: LifeArea has_many :life_journeys, dependent: :restrict_with_error
        @user.life_areas.destroy_all
        @user.strategy_point_ledgers.delete_all
        # Cascades daily_logs + completions via Habit dependent: :destroy.
        @user.habits.destroy_all
        @user.day_overshoot_bonuses.for_day(Date.current).delete_all
        @user.push_subscriptions.delete_all

        shown = Array(@user.support_milestones_shown).map(&:to_s)
        shown.delete(User::ADVENTURE_GUIDE_KEY)
        shown.delete(User::COMPANION_PICK_KEY)
        shown.delete(User::ONBOARDING_MOUNTAIN_TOUR_KEY)

        @user.update!(
          onboarding_completed_at: nil,
          planning_version: 2,
          strategy_points: 0,
          character: nil,
          climb_streak_days: 0,
          climb_streak_on: nil,
          climb_streak_freezes: 0,
          climb_streak_frozen_on: nil,
          day_shields_available: 1,
          day_shield_on: nil,
          support_milestones_shown: shown,
          push_offer_dismiss_count: 0,
          push_offer_dismissed_at: nil,
          push_offer_permission_denied_at: nil,
          install_offer_dismiss_count: 0,
          install_offer_dismissed_at: nil,
          install_offer_installed_at: nil,
          mountain_trail_tour_ack: 0
        )
      end

      @user
    end
  end
end
