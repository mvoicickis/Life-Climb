# frozen_string_literal: true

require "test_helper"

class StrategyGoalWeeklyRepeatTest < ActiveSupport::TestCase
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
    @camp_leaf = practice_leaf_for!(@camp)
  end

  test "day practice can repeat weekly with weekdays" do
    day = @user.strategy_goals.create!(
      life_area: @area,
      parent: @camp_leaf,
      horizon: "day",
      title: "Practice",
      scheduled_on: Date.current,
      repeat: "weekly",
      repeat_weekdays: [ Date.current.wday ],
      position: 0
    )

    assert day.repeat_weekly?
    assert day.repeats_on?(Date.current)
    refute day.repeats_on?(Date.current + 1.day)
  end

  test "weekly requires at least one weekday" do
    day = @user.strategy_goals.build(
      life_area: @area,
      parent: @camp_leaf,
      horizon: "day",
      title: "Practice",
      scheduled_on: Date.current,
      repeat: "weekly",
      repeat_weekdays: [],
      position: 0
    )

    refute day.valid?
    assert_includes day.errors[:repeat_weekdays], "can't be blank"
  end

  test "second weekly win on the same day after reopen does not skip the next occurrence" do
    anchor = Date.current
    next_wday = (anchor.wday + 2) % 7
    day = @user.strategy_goals.create!(
      life_area: @area,
      parent: @camp_leaf,
      horizon: "day",
      title: "Practice",
      scheduled_on: anchor,
      repeat: "weekly",
      repeat_weekdays: [ anchor.wday, next_wday ],
      position: 0
    )

    day.advance_recurring_schedule!(after: anchor)
    first_next = day.reload.scheduled_on

    day.advance_recurring_schedule!(after: anchor)

    assert_equal first_next, day.reload.scheduled_on
  end
end
