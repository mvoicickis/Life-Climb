# frozen_string_literal: true

module Strategy
  # True when the journey's root plan has path camps and every camp is finished.
  class SummitReached
    def self.on_journey?(user:, journey:)
      new(user:, journey:).on_journey?
    end

    def initialize(user:, journey:)
      @user = user
      @journey = journey
    end

    def on_journey?
      return false if @journey.blank?

      goal = Goals::Current.goal_for(user: @user, journey: @journey)
      plan = goal&.children&.for_kind("plan")&.not_holding&.ordered&.first
      return false if plan.blank?

      MountainTrailHelper.summit_reached_plan?(plan)
    end
  end
end
