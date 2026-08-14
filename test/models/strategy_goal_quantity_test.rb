# frozen_string_literal: true

require "test_helper"

class StrategyGoalQuantityTest < ActiveSupport::TestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @area = life_areas(:one_self)
    @goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    @plan = @user.strategy_goals.create!(
      life_area: @area, parent: @goal, horizon: "plan", title: "P", position: 0
    )
    @checkpoint = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Camp", position: 0
    )
  end

  test "path-level project accepts target_amount and unit" do
    @checkpoint.update!(target_amount: 700, unit: "pages")

    assert @checkpoint.quantified?
    assert_equal BigDecimal("700"), @checkpoint.target_amount
    assert_equal "pages", @checkpoint.unit
    assert_equal BigDecimal("0"), @checkpoint.current_amount
  end

  test "target_amount requires unit and must be positive" do
    @checkpoint.target_amount = 700
    @checkpoint.unit = nil
    assert_not @checkpoint.valid?
    assert_includes @checkpoint.errors[:unit], "can't be blank"

    @checkpoint.unit = "pages"
    @checkpoint.target_amount = 0
    assert_not @checkpoint.valid?
  end

  test "days cannot hold a quantity target" do
    day = @user.strategy_goals.create!(
      life_area: @area, parent: @checkpoint, horizon: "day",
      title: "Battle", scheduled_on: Date.current, position: 0
    )
    day.target_amount = 100
    day.unit = "pages"

    assert_not day.valid?
    assert day.errors[:target_amount].any?
  end

  test "non-project horizons reject target_amount" do
    @plan.target_amount = 10
    @plan.unit = "€"
    assert_not @plan.valid?
  end

  test "nested project under a quantified path camp is rejected" do
    @user.strategy_goals.create!(
      life_area: @area, parent: @checkpoint, horizon: "day",
      title: "Battle", scheduled_on: Date.current, position: 0
    )

    too_late = @user.strategy_goals.build(
      life_area: @area, parent: @checkpoint, horizon: "project", title: "Too late", position: 1
    )
    assert_not too_late.valid?
    assert too_late.errors[:parent_id].any?

    @checkpoint.update!(target_amount: 50, unit: "emails")
    assert @checkpoint.reload.quantified?
    assert @checkpoint.leaf_checkpoint?
  end

  test "quantified_path_project walks from day to path-level target" do
    @checkpoint.update!(target_amount: 200, unit: "emails")
    leaf = practice_leaf_for!(@checkpoint)
    day = @user.strategy_goals.create!(
      life_area: @area, parent: leaf, horizon: "day", title: "Send",
      scheduled_on: Date.current, position: 0
    )

    assert_equal @checkpoint, day.quantified_path_project
    assert_equal @checkpoint, leaf.quantified_path_project
  end

  test "non-quantified project percent stays binary" do
    assert_equal 0, Strategy::Progress.percent(@checkpoint)
    @checkpoint.complete!
    assert_equal 100, Strategy::Progress.percent(@checkpoint.reload)
  end

  test "creating any StrategyGoal with nil quantity fields does not raise" do
    assert_nothing_raised do
      goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "Plain goal", position: 1)
      plan = @user.strategy_goals.create!(
        life_area: @area, parent: goal, horizon: "plan", title: "Plain plan", position: 0
      )
      project = @user.strategy_goals.create!(
        life_area: @area, parent: plan, horizon: "project", title: "Plain project", position: 0
      )
      leaf = practice_leaf_for!(project)
      day = @user.strategy_goals.create!(
        life_area: @area, parent: leaf, horizon: "day", title: "Plain day",
        scheduled_on: Date.current, position: 0
      )

      assert_nil goal.target_amount
      assert_nil goal.unit
      assert_equal BigDecimal("0"), goal.current_amount
      assert_nil plan.unit
      assert_nil project.unit
      assert_nil day.unit
    end
  end
end
