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
      goal: 25,
      quantity_checkin: true
    )
  end

  test "quantity habit with unit times shows number input not Win-only" do
    get dashboard_path
    assert_response :success

    assert_select "#today_habit_#{@habit.id} form.lp-dash-tcard__qty .lp-dash-tcard__amount", count: 1
    assert_select "#today_habit_#{@habit.id} form.lp-dash-tcard__qty", count: 1
    assert_select "#today_habit_#{@habit.id} form[action=?]",
                  completions_path(habit_id: @habit.id),
                  count: 0
  end

  test "unlogged quantity habit renders blank required amount input with mode add" do
    get dashboard_path
    assert_response :success

    input = css_select("#today_habit_#{@habit.id} form.lp-dash-tcard__qty .lp-dash-tcard__amount").first
    assert input
    assert_equal "required", input["required"]
    value = input["value"].to_s
    assert value.blank? || value == "", "expected blank value, got #{value.inspect}"
    assert_select "#today_habit_#{@habit.id} form.lp-dash-tcard__qty input[name=mode][value=add]", count: 1
    assert_select "#today_habit_#{@habit.id} form.lp-dash-tcard__qty input[name=mode][value=set]", count: 0
  end

  test "logged quantity habit keeps add input blank and shows running total in meta" do
    @habit.daily_logs.create!(user: @user, logged_on: Date.current, amount: 7, goal: 25)
    get dashboard_path
    assert_response :success

    input = css_select("#today_habit_#{@habit.id} form.lp-dash-tcard__qty .lp-dash-tcard__amount").first
    assert input
    value = input["value"].to_s
    assert value.blank? || value == "", "expected blank add field, got #{value.inspect}"
    assert_match(/7 of 25/, response.body)
    assert_select "#today_habit_#{@habit.id} .lp-dash-habit__pct", text: "28%"
  end

  test "plus one form posts mode add only" do
    get dashboard_path
    assert_response :success
    assert_select "#today_habit_#{@habit.id} .lp-dash-habit__quick", count: 1
    # button_to wraps a form; ensure no set mode on the quick-add path
    assert_select "#today_habit_#{@habit.id} form input[name=mode][value=add]", minimum: 1
  end
end
