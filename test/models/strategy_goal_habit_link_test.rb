# frozen_string_literal: true

require "test_helper"

class StrategyGoalHabitLinkTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @area = life_areas(:one_self)
    @habit = habits(:one)
    @goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "Season", position: 0)
    @plan = @user.strategy_goals.create!(
      life_area: @area, parent: @goal, horizon: "plan", title: "Path", position: 0
    )
  end

  test "path-level project accepts many linked habits through join table" do
    project = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Improve", position: 0
    )
    HabitProjectLink.create!(habit: @habit, strategy_goal: project)

    assert_includes project.linked_habits, @habit
    assert_includes @habit.improvement_projects, project
    assert_nil(project.attributes["habit_id"]) if project.has_attribute?(:habit_id)
  end

  test "strategy_goals no longer store habit_id" do
    assert_not StrategyGoal.column_names.include?("habit_id")
  end
end
