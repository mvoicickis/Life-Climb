# frozen_string_literal: true

require "test_helper"

# Regression: after #305 additive logging + Today redesign toast, dashboard must not 500.
class TodayStandardHabitLogTest < ActionDispatch::IntegrationTest
  setup { enable_habits! }
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user)
    dismiss_onboarding_missions!(@user)

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
    assert_select "#today_habit_#{@habit.id}", count: 0
    assert_select ".lp-toast", text: /Added/
    assert_select ".lp-toast", text: /8 hours today/
    assert_today_v2_shell!
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
    assert_select "#today_habit_#{growth.id}", count: 0
    assert_select ".lp-toast", text: /Added/
    assert_today_v2_shell!
  end

  test "toast undo and menu undo both use session snapshot" do
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
    follow_redirect!

    post daily_logs_path(habit_id: growth.id),
         params: { mode: "undo", return_to: "today" }
    assert_redirected_to dashboard_path
    assert_equal BigDecimal("0"), growth.reload.today_amount
  end
end
