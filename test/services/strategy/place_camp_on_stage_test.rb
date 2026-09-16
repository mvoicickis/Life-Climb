# frozen_string_literal: true

require "test_helper"

class Strategy::PlaceCampOnStageTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    allow_extra_climbs!(@user)
    @area = @user.life_areas.first || @user.life_areas.create!(key: "career", number: 9)
    @goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "Goal", position: 0)
    @plan = @user.strategy_goals.create!(
      life_area: @area, parent: @goal, horizon: "plan", title: "Plan", position: 0
    )
    @a = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "A", position: 0, stage: 0
    )
    @b = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "B", position: 1, stage: 1
    )
    @c = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "C", position: 2, stage: 2
    )
  end

  test "places camp before later stages and shifts positions" do
    Strategy::PlaceCampOnStage.call(plan: @plan, camp: @c, stage: 0)

    assert_equal 0, @c.reload.stage
    assert_equal 1, @c.position
    assert_equal 0, @a.reload.position
    assert_equal 2, @b.reload.position
    assert_operator @c.position, :<, @b.position
  end

  test "appends when no later stages exist" do
    Strategy::PlaceCampOnStage.call(plan: @plan, camp: @a, stage: 2)

    assert_equal 2, @a.reload.stage
    assert_equal 3, @a.position
  end
end
