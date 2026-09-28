# frozen_string_literal: true

module Notifications
  # Next open battle title for push body — read-only.
  class OpenBattleTitle
    def self.for(user:, on:)
      new(user: user, on: on).call
    end

    def initialize(user:, on:)
      @user = user
      @on = on
    end

    def call
      title = from_todo || from_strategy_goals
      return nil if title.blank?

      PushGoalTitle.truncate(title, limit: 60)
    end

    private

    def from_todo
      eligible_todos.each do |todo|
        goal = todo.strategy_goal
        next if goal.present? && Battles::DoneOnDate.for(user: @user, goal: goal, on: @on)

        return todo.title
      end
      nil
    end

    def eligible_todos
      @user.daily_todos.for_day(@on).incomplete.ordered.select do |todo|
        next false if todo.strategy_goal_id.blank?

        goal = todo.strategy_goal
        next false if goal&.practice_tasks&.any?

        true
      end
    end

    def from_strategy_goals
      journey = @user.primary_focused_journey
      return nil if journey.blank?

      Strategy::DueDayBattles.on(user: @user, life_area: journey.life_area, on: @on).each do |goal|
        next if quest?(goal)
        next if Battles::DoneOnDate.for(user: @user, goal: goal, on: @on)

        return Strategy::EnsureFolderQuest.display_title_for(goal)
      end

      nil
    end

    def quest?(goal)
      goal.practice_tasks.any?
    end
  end
end
