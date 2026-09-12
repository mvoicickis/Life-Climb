# frozen_string_literal: true

require "test_helper"

class StrategyGoalStageTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    allow_extra_climbs!(@user)
    @area = @user.life_areas.first || @user.life_areas.create!(key: "career", number: 9)
    @goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "Stage goal", position: 0)
    @plan = @user.strategy_goals.create!(
      life_area: @area, parent: @goal, horizon: "plan", title: "Stage plan", position: 0
    )
  end

  test "first camp on empty plan gets stage zero" do
    camp = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "First", position: 0
    )

    assert_equal 0, camp.stage
  end

  test "second camp on plan gets max sibling stage plus one" do
    @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "First", position: 0
    )
    second = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Second", position: 1
    )

    assert_equal 1, second.stage
  end

  test "explicit stage wins over auto assign" do
    camp = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Pinned", position: 0, stage: 5
    )

    assert_equal 5, camp.stage
  end

  test "nested folder project under camp keeps default stage" do
    host = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Host", position: 0
    )
    folder = @user.strategy_goals.create!(
      life_area: @area, parent: host, horizon: "project", title: "Steps", position: 0
    )

    assert_equal 0, folder.stage
  end

  test "ordered_by_stage sorts stage then position then id" do
    middle = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Middle", position: 1, stage: 1
    )
    first = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "First", position: 0, stage: 0
    )

    assert_equal [ first.id, middle.id ], @plan.children.for_kind("project").ordered_by_stage.pluck(:id)
  end
end
