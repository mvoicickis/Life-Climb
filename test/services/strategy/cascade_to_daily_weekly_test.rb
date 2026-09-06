# frozen_string_literal: true

require "test_helper"

class Strategy::CascadeToDailyWeeklyTest < ActiveSupport::TestCase
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

  test "weekly template surfaces only on selected weekdays" do
    monday = Date.current.beginning_of_week(:monday)
    battle = @user.strategy_goals.create!(
      life_area: @area,
      parent: @camp_leaf,
      horizon: "day",
      title: "Mon/Wed/Fri",
      scheduled_on: monday,
      repeat: "weekly",
      repeat_weekdays: [ 1, 3, 5 ],
      position: 0
    )

    Strategy::CascadeToDaily.call(
      user: @user,
      life_area: @area,
      from: monday,
      to: monday + 6.days
    )

    assert @user.daily_todos.exists?(strategy_goal_id: battle.id, scheduled_on: monday)
    assert @user.daily_todos.exists?(strategy_goal_id: battle.id, scheduled_on: monday + 2.days)
    assert @user.daily_todos.exists?(strategy_goal_id: battle.id, scheduled_on: monday + 4.days)
    refute @user.daily_todos.exists?(strategy_goal_id: battle.id, scheduled_on: monday + 1.day)
  end

  test "completing weekly battle advances to next selected weekday" do
    battle = @user.strategy_goals.create!(
      life_area: @area,
      parent: @camp_leaf,
      horizon: "day",
      title: "Mon/Wed",
      scheduled_on: Date.current,
      repeat: "weekly",
      repeat_weekdays: [ Date.current.wday, (Date.current.wday + 2) % 7 ],
      position: 0
    )

    todo = Strategy::CascadeToDaily.sync_goal!(user: @user, goal: battle)
    Battles::CompleteTodo.call(todo: todo, user: @user, session: {})

    expected = battle.reload.next_weekly_occurrence(after: Date.current)
    assert_equal expected, battle.scheduled_on
    assert_nil battle.completed_at
  end
end
