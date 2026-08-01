# frozen_string_literal: true

require "test_helper"

class StrategyGoalRepeatTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @area = life_areas(:one_self)
    @goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "Goal", position: 0)
    @plan = @user.strategy_goals.create!(
      life_area: @area, parent: @goal, horizon: "plan", title: "Plan", position: 0
    )
    @camp = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Camp", position: 0
    )
  end

  test "day practice can repeat daily" do
    day = @user.strategy_goals.create!(
      life_area: @area, parent: @camp, horizon: "day",
      title: "Do lessons", scheduled_on: Date.current, repeat: "daily", position: 0
    )
    assert day.repeat_daily?
    assert_equal "daily", day.repeat
  end

  test "non-day goals normalize daily repeat back to none" do
    @plan.repeat = "daily"
    assert @plan.valid?
    assert_equal "none", @plan.repeat
    assert_not @plan.repeat_daily?
  end

  test "blank repeat normalizes to none" do
    day = @user.strategy_goals.build(
      life_area: @area, parent: @camp, horizon: "day",
      title: "Once", scheduled_on: Date.current, repeat: nil, position: 0
    )
    assert day.valid?
    assert_equal "none", day.repeat
    assert_not day.repeat_daily?
  end
end
