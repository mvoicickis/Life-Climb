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

  test "non-developer does not see anytime on Today V2 even when GameRules enables habits" do
    enable_habits!

    get dashboard_path
    assert_response :success

    assert_today_v2_shell!
    assert_select ".lp-dash-anytime", count: 0
    assert_select "#today_habit_#{@habit.id}", count: 0
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
end
