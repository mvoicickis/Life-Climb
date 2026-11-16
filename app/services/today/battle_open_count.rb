# frozen_string_literal: true

module Today
  # Open battles on Today (Fight notch count) — mirrors Dashboard::TodaySurface#assign_today_battle_surface!.
  class BattleOpenCount
    def self.for(user:, on: Date.current)
      new(user: user, on: on).call
    end

    def initialize(user:, on:)
      @user = user
      @on = on
    end

    def call
      journey = @user.primary_focused_journey
      return 0 if journey.blank?

      strategy_goal = Goals::Current.goal_for(user: @user, journey: journey)
      daily_todos = Today::FocusedDayTodos.relation(
        user: @user,
        journey: journey,
        goal: strategy_goal,
        on: @on
      ).ordered.to_a
      open_todos = daily_todos.reject(&:completed?)

      first_climb_needed = strategy_goal.present? && strategy_goal.children.for_kind("plan").not_holding.none?
      show_plan_route = first_climb_needed || plan_route_pending?(journey, daily_todos, strategy_goal)

      mission = journey.missions.for_day(@on).primary.incomplete.order(:id).first ||
                journey.missions.for_day(@on).primary.order(:id).first
      include_mission = !show_plan_route && mission.present? && mission.status == "pending"

      open_todos.size + (include_mission ? 1 : 0)
    end

    private

    def plan_route_pending?(journey, daily_todos, strategy_goal)
      return false unless journey.setup_flag(Onboarding::Run::ROUTE_FLAG) == "pending"
      return false if strategy_day_battles?(daily_todos, strategy_goal)

      mission = journey.missions.for_day(@on).primary.order(:id).first
      mission.present? && !mission.completed?
    end

    def strategy_day_battles?(daily_todos, strategy_goal)
      return true if daily_todos.any? { |t| t.tag.to_s == "strategy" || t.strategy_goal_id.present? }
      return false if strategy_goal.blank?

      Strategy::Progress.battles_under(strategy_goal).any?
    end
  end
end
