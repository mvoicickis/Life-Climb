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

  test "path-level project accepts habit for same user" do
    project = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Improve", position: 0, habit: @habit
    )
    assert_equal @habit.id, project.habit_id
    assert_includes @habit.improvement_projects, project
  end

  test "rejects habit_id on non-project horizons" do
    @plan.habit = @habit
    assert_not @plan.valid?
    assert @plan.errors[:habit_id].any?
  end

  test "rejects habit belonging to another user" do
    other_habit = habits(:two)
    project = @user.strategy_goals.build(
      life_area: @area, parent: @plan, horizon: "project", title: "Steal", position: 0, habit: other_habit
    )
    assert_not project.valid?
    assert project.errors[:habit_id].any?
  end
end
