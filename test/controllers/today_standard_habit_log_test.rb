# frozen_string_literal: true

require "test_helper"

# Regression: after #305 additive logging, Today shows an undo strip that formats
# session-stored delta/total strings. A GET /dashboard after logging must not 500.
class TodayStandardHabitLogTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user)

    @user.habits.active.on_home.destroy_all
    @habit = @user.habits.create!(
      name: "Sleep",
      unit: "hours",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "standard",
      min_value: 7,
      max_value: 9,
      goal: nil,
      quantity_checkin: true
    )
  end

  test "logging a standard quantity habit then loading Today does not 500" do
    assert_nil @habit.goal_progress_percent

    post daily_logs_path(habit_id: @habit.id),
         params: { mode: "add", return_to: "today", daily_log: { amount: "8" } }
    assert_redirected_to dashboard_path
    assert_equal BigDecimal("8"), @habit.reload.today_amount

    follow_redirect!
    assert_response :success
    assert_select "#today_habit_#{@habit.id}"
    assert_select ".lp-dash-habit__undo", text: /Added/
    assert_select ".lp-dash-habit__undo", text: /8 hours today/
  end

  test "logging a growth quantity habit then loading Today does not 500" do
    growth = @user.habits.create!(
      name: "Pages",
      unit: "pages",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "growth",
      goal: 10,
      quantity_checkin: true
    )

    post daily_logs_path(habit_id: growth.id),
         params: { mode: "add", return_to: "today", daily_log: { amount: "3" } }
    assert_redirected_to dashboard_path

    follow_redirect!
    assert_response :success
    assert_select "#today_habit_#{growth.id} .lp-dash-habit__undo", text: /Added/
  end
end
