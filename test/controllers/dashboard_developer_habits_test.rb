# frozen_string_literal: true

require "test_helper"

class DashboardDeveloperHabitsTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @user.update_columns(developer: false)
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
    dismiss_onboarding_missions!(@user)
    @user.habits.destroy_all
    @habit = @user.habits.create!(
      name: "Push-Ups",
      unit: "reps",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "growth",
      goal: 25,
      quantity_checkin: true
    )
  end

  test "non-developer sees anytime on Today V2 when GameRules enables habits" do
    enable_habits!

    get dashboard_path
    assert_response :success

    assert_today_v2_shell!
    assert_select ".lp-dash-anytime", count: 1
    assert_select "#today_habit_#{@habit.id}", count: 1
  end

  test "developer sees anytime on Today V2 battlefield" do
    @user.update_columns(developer: true)

    get dashboard_path
    assert_response :success

    assert_today_v2_shell!
    assert_select ".lp-dash-anytime", count: 1
    assert_select "#today_habit_#{@habit.id}", count: 1
    assert_select ".lp-dash-anytime .lp-dash-tcard__title", text: "Push-Ups"
  end

  test "developer basics header counts survived habits not stretch goal completion only" do
    @user.update_columns(developer: true)
    @habit.update!(goal: nil, name: "Steps", unit: "steps")
    @habit.daily_logs.create!(user: @user, logged_on: Date.current, amount: 2000)

    binary = @user.habits.create!(
      name: "Meditate", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, quantity_checkin: false
    )
    binary.completions.create!(user: @user, completed_on: Date.current, points_awarded: 5)

    growth_goal = @user.habits.create!(
      name: "Duo", unit: "lessons", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", goal: 10,
      quantity_checkin: true
    )
    growth_goal.daily_logs.create!(user: @user, logged_on: Date.yesterday, amount: 5)
    growth_goal.daily_logs.create!(user: @user, logged_on: Date.current, amount: 15)

    get dashboard_path
    assert_response :success

    assert_select ".lp-dash-anytime__count", text: "3/3"
  end

  test "developer sees plain amount for growth habit without stretch goal" do
    @user.update_columns(developer: true)
    @habit.update!(goal: nil)
    @habit.daily_logs.create!(user: @user, logged_on: Date.current, amount: 7, goal: 1)

    get dashboard_path
    assert_response :success

    assert_select "#today_habit_#{@habit.id} .lp-dash-tcard__meta", text: /7 reps/
    meta = css_select("#today_habit_#{@habit.id} .lp-dash-tcard__meta").first
    assert_not_includes meta.text, "of 1"
    assert_select "#today_habit_#{@habit.id} .lp-dash-habit__pct", count: 0
    assert_select "#today_habit_#{@habit.id}[data-tcard-menu-portal-value='true']"
    assert_select "#today_habit_#{@habit.id} [data-tcard-menu-target='sheet']"
  end
end
