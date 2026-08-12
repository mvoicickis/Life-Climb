# frozen_string_literal: true

require "test_helper"

class HabitGoalProgressPercentTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "growth habit percentage is uncapped past target" do
    habit = @user.habits.create!(
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
    habit.daily_logs.create!(user: @user, logged_on: Date.current, amount: 30, goal: 25)

    assert_equal 120, habit.goal_progress_percent
  end

  test "binary habit is 0 or 100" do
    habit = @user.habits.create!(
      name: "Meditate",
      unit: "times",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "growth",
      quantity_checkin: false
    )

    assert_equal 0, habit.goal_progress_percent
    habit.completions.create!(user: @user, completed_on: Date.current, points_awarded: 5)
    assert_equal 100, habit.reload.goal_progress_percent
  end

  test "standard healthy-range habit has no percentage" do
    habit = @user.habits.create!(
      name: "Sleep",
      unit: "hours",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "standard",
      min_value: 7,
      max_value: 9,
      quantity_checkin: true
    )
    habit.daily_logs.create!(user: @user, logged_on: Date.current, amount: 10)

    assert_nil habit.goal_progress_percent
  end
end
