# frozen_string_literal: true

require "test_helper"

class Strategy::CascadeToDailyRepeatTest < ActiveSupport::TestCase
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

  test "daily template gets a fresh todo after today is completed" do
    @camp_leaf = practice_leaf_for!(@camp)
    practice = @user.strategy_goals.create!(
      life_area: @area, parent: @camp_leaf, horizon: "day",
      title: "Do lessons", scheduled_on: Date.current, repeat: "daily", position: 0
    )

    Strategy::CascadeToDaily.call(
      user: @user, life_area: @area, from: Date.current, to: Date.current + 1.day
    )
    today_todo = @user.daily_todos.find_by!(strategy_goal_id: practice.id, scheduled_on: Date.current)
    assert_not today_todo.completed?

    today_todo.update!(completed_at: Time.current)
    practice.update!(scheduled_on: Date.current + 1.day, completed_at: nil)

    Strategy::CascadeToDaily.call(
      user: @user, life_area: @area, from: Date.current, to: Date.current + 1.day
    )
    tomorrow_todo = @user.daily_todos.find_by(strategy_goal_id: practice.id, scheduled_on: Date.current + 1.day)
    assert_not_nil tomorrow_todo
    assert_not tomorrow_todo.completed?
    assert practice.reload.repeat_daily?
    assert_nil practice.completed_at
  end

  test "one-time completed todo is not recreated" do
    @camp_leaf = practice_leaf_for!(@camp)
    practice = @user.strategy_goals.create!(
      life_area: @area, parent: @camp_leaf, horizon: "day",
      title: "Once", scheduled_on: Date.current, repeat: "none", position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area, from: Date.current, to: Date.current)
    todo = @user.daily_todos.find_by!(strategy_goal_id: practice.id, scheduled_on: Date.current)
    todo.update!(completed_at: Time.current)
    practice.complete!

    created = Strategy::CascadeToDaily.call(
      user: @user, life_area: @area, from: Date.current, to: Date.current + 1.day
    )
    assert_equal 0, created
    assert_equal 1, @user.daily_todos.where(strategy_goal_id: practice.id).count
  end
end
