# frozen_string_literal: true

require "test_helper"

class StrategyGoalTrailCoordsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @area = @user.life_areas.first || @user.life_areas.create!(key: "career", number: 9)
    @goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    @plan = @user.strategy_goals.create!(
      life_area: @area, parent: @goal, horizon: "plan", title: "P", position: 0
    )
    @project = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Camp", position: 0
    )
  end

  test "path project accepts trail coords in 0..1" do
    assert @project.update(trail_x: 0.42, trail_y: 0.58)
    assert_in_delta 0.42, @project.reload.trail_x, 0.0001
    assert_in_delta 0.58, @project.trail_y, 0.0001
  end

  test "path project may leave trail coords nil for auto-slot" do
    assert @project.valid?
    assert_nil @project.trail_x
    assert_nil @project.trail_y
  end

  test "rejects trail coords outside 0..1" do
    @project.trail_x = 1.2
    @project.trail_y = 0.5
    assert_not @project.valid?
    assert @project.errors[:trail_x].any?
  end

  test "rejects half-set trail coords" do
    @project.trail_x = 0.3
    @project.trail_y = nil
    assert_not @project.valid?
    assert @project.errors[:trail_y].any?
  end

  test "holding camp cannot keep trail coords" do
    holding_plan = @user.strategy_goals.create!(
      life_area: @area, parent: @goal, horizon: "plan", title: "Hold plan",
      position: 99, holding: true
    )
    holding = @user.strategy_goals.create!(
      life_area: @area, parent: holding_plan, horizon: "project", title: "Hold camp",
      position: 0, holding: true
    )
    holding.trail_x = 0.5
    holding.trail_y = 0.5
    holding.valid?
    assert_nil holding.trail_x
    assert_nil holding.trail_y
  end

  test "plans clear trail coords on normalize" do
    @plan.trail_x = 0.2
    @plan.trail_y = 0.3
    assert @plan.valid?
    assert_nil @plan.trail_x
    assert_nil @plan.trail_y
  end
end
