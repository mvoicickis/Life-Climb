# frozen_string_literal: true

require "test_helper"

class TodayOvershootBonusTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @user.update!(planning_version: 2, total_points: 200, character: "fox")
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
    @user.habits.active.on_home.destroy_all
    @user.daily_todos.for_day(Date.current).delete_all

    @habit = @user.habits.create!(
      name: "Push-Ups", unit: "reps", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", goal: 100, quantity_checkin: true
    )
  end

  test "GET dashboard does not create overshoot row or change points when above 100" do
    entry = @user.daily_logs.create!(habit: @habit, logged_on: Date.current, amount: 168, goal: 100)
    assert entry.persisted?
    assert_operator Today::DayPercent.call(user: @user).percent, :>, 100

    assert_no_difference -> { DayOvershootBonus.count } do
      assert_no_difference -> { @user.reload.total_points } do
        get dashboard_path
        assert_response :success
      end
    end

    # Card shows percent without AP when no bonus row exists yet.
    assert_select "[data-day-overshoot='true']", text: /168% of your day/
    assert_select "[data-day-overshoot='true']", text: /bonus AP/, count: 0
  end

  test "logging past 100 on Today awards bonus and shows card with AP" do
    post daily_logs_path(habit_id: @habit.id),
         params: { mode: "add", return_to: "today", daily_log: { amount: "168" } }
    assert_redirected_to dashboard_path

    bonus = DayOvershootBonus.find_by!(user: @user, on_date: Date.current)
    assert_equal 27, bonus.awarded_ap
    assert_equal 27, @user.life_point_ledgers.where(source: bonus).sum(:amount)
    # Rhythm AP (+5) may also fire when the growth goal is met — overshoot is separate.
    assert_operator @user.reload.total_points, :>=, 227

    follow_redirect!
    assert_response :success
    assert_select "[data-day-overshoot='true']", text: /168% of your day · \+27 bonus AP/
  end

  test "card absent at or below 100 percent" do
    post daily_logs_path(habit_id: @habit.id),
         params: { mode: "add", return_to: "today", daily_log: { amount: "100" } }
    follow_redirect!
    assert_response :success
    assert_select "[data-day-overshoot='true']", count: 0
  end

  test "commitment survival UI is unchanged when overshoot card appears" do
    post daily_logs_path(habit_id: @habit.id),
         params: { mode: "add", return_to: "today", daily_log: { amount: "168" } }
    follow_redirect!
    assert_response :success
    assert_select "[data-day-overshoot='true']"
    # Survival still comes from commitment / next-action — not replaced by %.
    assert_select ".lp-dash-overshoot__title", text: /of your day/
    refute_match(/Day survived/, css_select("[data-day-overshoot='true']").to_html)
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password12345" }
  end
end
