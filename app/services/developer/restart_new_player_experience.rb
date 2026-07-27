# frozen_string_literal: true

module Developer
  # Resets New Player Experience flags only.
  # Never deletes Goals, Plans, Projects, Battles, journeys, or the user account.
  class RestartNewPlayerExperience
    def self.call(user:)
      new(user:).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      shown = Array(@user.support_milestones_shown).map(&:to_s)
      shown.delete(User::ADVENTURE_GUIDE_KEY)

      @user.update!(
        onboarding_completed_at: nil,
        planning_version: 2,
        support_milestones_shown: shown
      )
      @user
    end
  end
end
