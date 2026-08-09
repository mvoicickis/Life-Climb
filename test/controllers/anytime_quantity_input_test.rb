# frozen_string_literal: true

require "test_helper"

class AnytimeQuantityInputTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
    @user.habits.destroy_all
    @habit = @user.habits.create!(
      name: "Push-Ups",
      unit: "times",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "growth",
      quantity_checkin: true
    )
  end

  test "quantity habit with unit times shows number input not Win-only" do
    get dashboard_path
    assert_response :success

    assert_select "#today_habit_#{@habit.id} .lp-dash-tcard__amount", count: 1
    assert_select "#today_habit_#{@habit.id} form.lp-dash-tcard__qty", count: 1
    assert_select "#today_habit_#{@habit.id} form[action=?]",
                  completions_path(habit_id: @habit.id),
                  count: 0
  end

  test "unlogged quantity habit renders blank required amount input" do
    get dashboard_path
    assert_response :success

    input = css_select("#today_habit_#{@habit.id} .lp-dash-tcard__amount").first
    assert input
    assert_equal "required", input["required"]
    value = input["value"].to_s
    assert value.blank? || value == "", "expected blank value, got #{value.inspect}"
  end

  test "logged quantity habit prefills real amount including zero" do
    @habit.daily_logs.create!(user: @user, logged_on: Date.current, amount: 7)
    get dashboard_path
    assert_response :success
    assert_select "#today_habit_#{@habit.id} .lp-dash-tcard__amount[value=?]", "7"

    @habit.daily_logs.find_by!(logged_on: Date.current).update!(amount: 0)
    get dashboard_path
    assert_response :success
    assert_select "#today_habit_#{@habit.id} .lp-dash-tcard__amount[value=?]", "0"
  end
end
