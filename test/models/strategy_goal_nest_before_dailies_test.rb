# frozen_string_literal: true

require "test_helper"

class StrategyGoalNestBeforeDailiesTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @area = life_areas(:one_self)
    @goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "Goal", position: 0)
    @plan = @user.strategy_goals.create!(
      life_area: @area, parent: @goal, horizon: "plan", title: "Find a job", position: 0
    )
    @camp = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Learn German", position: 0
    )
  end

  test "path_level_camp and nested_leaf_camp helpers" do
    assert @camp.path_level_camp?
    assert_not @camp.nested_leaf_camp?

    nested = @user.strategy_goals.create!(
      life_area: @area, parent: @camp, horizon: "project", title: "Vocabulary", position: 0
    )
    assert nested.nested_leaf_camp?
    assert_not nested.path_level_camp?
    assert_not @camp.reload.nested_leaf_camp?
    assert @camp.branch_checkpoint?
  end

  test "day under Path-level camp is rejected on create" do
    day = @user.strategy_goals.build(
      life_area: @area, parent: @camp, horizon: "day",
      title: "Do lessons", scheduled_on: Date.current, position: 0
    )

    assert_not day.valid?
    assert_includes day.errors[:base], I18n.t("strategy.rpg.day_needs_nested_camp")
  end

  test "day under nested camp is accepted" do
    nested = @user.strategy_goals.create!(
      life_area: @area, parent: @camp, horizon: "project", title: "Vocabulary", position: 0
    )
    day = @user.strategy_goals.create!(
      life_area: @area, parent: nested, horizon: "day",
      title: "Do lessons", scheduled_on: Date.current, position: 0
    )

    assert day.persisted?
    assert_equal nested.id, day.parent_id
  end

  test "existing day under Path-level camp can still update" do
    day = @user.strategy_goals.new(
      life_area: @area, parent: @camp, horizon: "day",
      title: "Legacy lesson", scheduled_on: Date.current, position: 0
    )
    day.save!(validate: false)

    day.update!(title: "Legacy lesson renamed", scheduled_on: Date.current + 1.day)
    assert_equal "Legacy lesson renamed", day.reload.title
    assert_equal Date.current + 1.day, day.scheduled_on
  end
end
