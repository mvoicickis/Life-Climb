# frozen_string_literal: true

require "test_helper"

class HabitSurvivedTodayTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "binary habit survives when completed today" do
    habit = @user.habits.create!(
      name: "Meditate", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, quantity_checkin: false
    )

    assert_not habit.survived_today?
    habit.completions.create!(user: @user, completed_on: Date.current, points_awarded: habit.points)
    assert habit.survived_today?
  end

  test "quantity habit survives on better or perfect tone" do
    habit = @user.habits.create!(
      name: "Push-ups", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", goal: 20,
      quantity_checkin: true
    )
    habit.daily_logs.create!(logged_on: Date.yesterday, amount: 10)
    habit.daily_logs.create!(logged_on: Date.current, amount: 12)

    assert_equal :better, HabitStatusEvaluator.new(habit).call
    assert habit.survived_today?
  end

  test "growth with no goal survives when amount is positive" do
    habit = @user.habits.create!(
      name: "Walk", unit: "steps", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", goal: nil,
      quantity_checkin: true
    )
    habit.daily_logs.create!(logged_on: Date.current, amount: 5)

    assert habit.survived_today?
  end

  test "same with zero does not count as survived" do
    habit = @user.habits.create!(
      name: "Walk", unit: "steps", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", goal: nil,
      quantity_checkin: true
    )
    habit.daily_logs.create!(logged_on: Date.yesterday, amount: 0)
    habit.daily_logs.create!(logged_on: Date.current, amount: 0)

    assert_equal :same, HabitStatusEvaluator.new(habit).call
    assert_not habit.survived_today?
  end

  test "unfiled habit can still survive" do
    habit = @user.habits.create!(
      name: "Water", unit: "glasses", points: 5, frequency: "daily",
      active: true, show_on_home: true, area_id: nil, quantity_checkin: false
    )
    habit.completions.create!(user: @user, completed_on: Date.current, points_awarded: habit.points)

    assert_nil habit.area_id
    assert habit.survived_today?
  end
end
