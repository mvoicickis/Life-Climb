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

  test "path-level camp is not a nested leaf" do
    assert @camp.path_level_camp?
    assert_not @camp.nested_leaf_camp?
    assert_not @camp.branch_checkpoint?
    assert_not @camp.split_eligible?
  end

  test "day under Path-level camp is accepted" do
    day = @user.strategy_goals.create!(
      life_area: @area, parent: @camp, horizon: "day",
      title: "Do lessons", scheduled_on: Date.current, position: 0
    )

    assert day.persisted?
    assert_equal @camp.id, day.parent_id
  end

  test "nested project under Path-level camp is rejected" do
    nested = @user.strategy_goals.build(
      life_area: @area, parent: @camp, horizon: "project", title: "Vocabulary", position: 0
    )

    assert_not nested.valid?
    assert nested.errors[:parent_id].any?
  end
end
