# frozen_string_literal: true

module Today
  # Open battles on Today (Fight notch count) — mirrors Dashboard::TodaySurface#assign_today_battle_surface!.
  # Todos only: daily missions are not battles and are never counted.
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

      daily_todos.reject(&:completed?).size
    end
  end
end
