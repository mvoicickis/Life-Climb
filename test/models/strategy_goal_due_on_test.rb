# frozen_string_literal: true

require "test_helper"

class StrategyGoalDueOnTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @area = @user.life_areas.first || @user.life_areas.create!(key: "career", name: "Career", position: 0)
    @journey = @user.life_journeys.create!(
      life_area: @area,
      title: "Ship",
      ideal_scene: "Shipped",
      current_reality: "Building",
      status: "active"
    )
  end

  test "new goal without due_on gets one year default" do
    goal = @user.strategy_goals.create!(
      life_area: @area,
      life_journey: @journey,
      horizon: "goal",
      title: "Climb",
      position: 0
    )

    assert_equal Strategy::YearCycle.default_goal_due, goal.due_on
  end

  test "explicit due_on wins over the default" do
    custom = Date.current + 90.days
    goal = @user.strategy_goals.create!(
      life_area: @area,
      life_journey: @journey,
      horizon: "goal",
      title: "Climb",
      due_on: custom,
      position: 0
    )

    assert_equal custom, goal.due_on
  end

  test "existing past due_on is left alone on unrelated updates" do
    goal = @user.strategy_goals.create!(
      life_area: @area,
      life_journey: @journey,
      horizon: "goal",
      title: "Legacy",
      due_on: Date.current + 30.days,
      position: 0
    )
    # Simulate a legacy Dec 29 / past date already stored.
    goal.update_columns(due_on: Date.new(2020, 12, 29))

    assert goal.update(title: "Legacy renamed")
    assert_equal Date.new(2020, 12, 29), goal.reload.due_on
  end

  test "changing due_on to a past date is rejected" do
    goal = @user.strategy_goals.create!(
      life_area: @area,
      life_journey: @journey,
      horizon: "goal",
      title: "Climb",
      position: 0
    )

    assert_not goal.update(due_on: Date.current - 1.day)
    assert_includes goal.errors[:due_on], "is invalid"
  end
end
