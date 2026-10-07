# frozen_string_literal: true

module Strategy
  # Shared spine resolver for QuickAdd / EnsureDayForTodo / Handoff.
  # Picks the trail-current path-level Project on the first plan that still
  # has one, or the hidden holding camp when none exist (ensure!).
  class PathProject
    def self.resolve(user:, journey:)
      new(user:, journey:).resolve
    end

    def self.ensure!(user:, journey:, title:)
      new(user:, journey:).ensure!(title)
    end

    def initialize(user:, journey:)
      @user = user
      @journey = journey
    end

    def resolve
      goal = root_goal
      return nil if goal.blank?

      goal.children.for_kind("plan").not_holding.ordered.each do |plan|
        camp = Trail.current_camp_for(plan: plan)
        return camp if camp
      end

      nil
    end

    def ensure!(_title)
      found = resolve
      return found if found

      HoldingProject.ensure!(user: @user, journey: @journey)
    end

    private

    def root_goal
      @root_goal ||= Goals::Current.goal_for(user: @user, journey: @journey)
    end
  end
end
