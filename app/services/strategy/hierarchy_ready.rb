# frozen_string_literal: true

module Strategy
  # True when the player has Goal → Plan → Project → Battle under a journey.
  class HierarchyReady
    def self.call(user:, journey: nil, goal: nil)
      new(user:, journey:, goal:).call
    end

    def initialize(user:, journey: nil, goal: nil)
      @user = user
      @journey = journey
      @goal = goal
    end

    def call
      root = resolve_goal
      return false if root.blank?

      plan_ids = root.children.for_kind("plan").pluck(:id)
      return false if plan_ids.empty?

      project_ids = StrategyGoal.where(parent_id: plan_ids).for_kind("project").pluck(:id)
      return false if project_ids.empty?

      Strategy::Progress.battles_under(root).any?
    end

    private

    def resolve_goal
      return @goal if @goal.present?

      journey = @journey || @user.primary_focused_journey || @user.life_journeys.active.order(:id).first
      return nil if journey.blank?

      @user.strategy_goals.for_area(journey.life_area_id).for_kind("goal").roots.first
    end
  end
end
