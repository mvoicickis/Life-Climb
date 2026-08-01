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

  test "empty checkpoint is a leaf and split-eligible" do
    assert @checkpoint.leaf_checkpoint?
    assert_not @checkpoint.branch_checkpoint?
    assert @checkpoint.split_eligible?
  end

  test "nested leaf checkpoint can take day children" do
    nested = practice_leaf_for!(@checkpoint)
    day = @user.strategy_goals.create!(
      life_area: @area, parent: nested, horizon: "day",
      title: "Battle", scheduled_on: Date.current, position: 0
    )

    assert day.persisted?
    assert nested.reload.leaf_checkpoint?
    assert_not nested.split_eligible?
  end

  test "path-level leaf cannot take new day children" do
    day = @user.strategy_goals.build(
      life_area: @area, parent: @checkpoint, horizon: "day",
      title: "Battle", scheduled_on: Date.current, position: 0
    )

    assert_not day.valid?
    assert_includes day.errors[:base], I18n.t("strategy.rpg.day_needs_nested_camp")
  end

  test "split creates project children under the checkpoint" do
    child = @user.strategy_goals.create!(
      life_area: @area, parent: @checkpoint, horizon: "project", title: "Smaller camp", position: 0
    )

    assert child.persisted?
    assert_equal @checkpoint.id, child.parent_id
    assert @checkpoint.reload.branch_checkpoint?
    assert_not @checkpoint.leaf_checkpoint?
    assert @checkpoint.split_eligible?
  end

  test "split is blocked when day children exist" do
    nested = practice_leaf_for!(@checkpoint)
    @user.strategy_goals.create!(
      life_area: @area, parent: nested, horizon: "day",
      title: "Open battle", scheduled_on: Date.current, position: 0
    )

    too_late = @user.strategy_goals.build(
      life_area: @area, parent: nested, horizon: "project", title: "Too late", position: 1
    )

    assert_not too_late.valid?
    assert_includes too_late.errors[:base],
                    "Remove or finish steps on this checkpoint before splitting it."
  end

  test "split is blocked when completed day children exist" do
    nested = practice_leaf_for!(@checkpoint)
    day = @user.strategy_goals.create!(
      life_area: @area, parent: nested, horizon: "day",
      title: "Done battle", scheduled_on: Date.current, position: 0
    )
    day.complete!

    too_late = @user.strategy_goals.build(
      life_area: @area, parent: nested, horizon: "project", title: "Still blocked", position: 1
    )

    assert_not too_late.valid?
    assert_includes too_late.errors[:base],
                    "Remove or finish steps on this checkpoint before splitting it."
  end

  test "branch checkpoint cannot take day children" do
    @user.strategy_goals.create!(
      life_area: @area, parent: @checkpoint, horizon: "project", title: "Child camp", position: 0
    )

    day = @user.strategy_goals.build(
      life_area: @area, parent: @checkpoint, horizon: "day",
      title: "Wrong place", scheduled_on: Date.current, position: 1
    )

    assert_not day.valid?
    assert day.errors[:base].any?
  end

  test "nested child can take dailies or split again" do
    mid = @user.strategy_goals.create!(
      life_area: @area, parent: @checkpoint, horizon: "project", title: "Mid camp", position: 0
    )
    leaf = @user.strategy_goals.create!(
      life_area: @area, parent: mid, horizon: "project", title: "Deep camp", position: 0
    )
    day = @user.strategy_goals.create!(
      life_area: @area, parent: leaf, horizon: "day",
      title: "Deep battle", scheduled_on: Date.current, position: 0
    )

    assert day.persisted?
    assert mid.reload.branch_checkpoint?
    assert leaf.reload.leaf_checkpoint?
    assert_not leaf.split_eligible?

    other_mid = @user.strategy_goals.create!(
      life_area: @area, parent: @checkpoint, horizon: "project", title: "Sibling mid", position: 1
    )
    assert other_mid.split_eligible?
  end
end
