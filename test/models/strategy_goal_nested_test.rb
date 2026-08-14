# frozen_string_literal: true

require "test_helper"

class StrategyGoalNestedTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @area = life_areas(:one_self)
    @goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "Goal", position: 0)
    @plan = @user.strategy_goals.create!(
      life_area: @area, parent: @goal, horizon: "plan", title: "Plan", position: 0
    )
    @checkpoint = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Camp", position: 0
    )
  end

  test "empty path camp is a leaf and cannot split into nested projects" do
    assert @checkpoint.leaf_checkpoint?
    assert_not @checkpoint.branch_checkpoint?
    assert_not @checkpoint.split_eligible?
  end

  test "path-level camp can take day children" do
    day = @user.strategy_goals.create!(
      life_area: @area, parent: @checkpoint, horizon: "day",
      title: "Battle", scheduled_on: Date.current, position: 0
    )

    assert day.persisted?
    assert @checkpoint.reload.leaf_checkpoint?
    assert_not @checkpoint.split_eligible?
  end

  test "nested project under a path camp is rejected" do
    child = @user.strategy_goals.build(
      life_area: @area, parent: @checkpoint, horizon: "project", title: "Smaller camp", position: 0
    )

    assert_not child.valid?
    assert child.errors[:parent_id].any?
  end

  test "nested project is still rejected when the camp already has days" do
    @user.strategy_goals.create!(
      life_area: @area, parent: @checkpoint, horizon: "day",
      title: "Open battle", scheduled_on: Date.current, position: 0
    )

    too_late = @user.strategy_goals.build(
      life_area: @area, parent: @checkpoint, horizon: "project", title: "Too late", position: 1
    )

    assert_not too_late.valid?
    assert too_late.errors[:parent_id].any?
  end
end
