# frozen_string_literal: true

require "test_helper"

class Today::DayPercentTest < ActiveSupport::TestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    seed_climb!(@user, today_mission: "Ship auth")
    @user.habits.active.on_home.destroy_all
  end

  test "averages growth uncapped, binary, and battles; excludes standard" do
    @user.habits.create!(
      name: "Push-Ups", unit: "reps", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", goal: 25, quantity_checkin: true
    ).tap { |h| @user.daily_logs.create!(habit: h, logged_on: Date.current, amount: 30, goal: 25) }

    @user.habits.create!(
      name: "Meditate", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", quantity_checkin: false
    ).tap { |h| @user.completions.create!(habit: h, completed_on: Date.current) }

    @user.habits.create!(
      name: "Sleep", unit: "hours", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "standard",
      min_value: 7, max_value: 9, goal: nil, quantity_checkin: true
    ).tap { |h| @user.daily_logs.create!(habit: h, logged_on: Date.current, amount: 8) }

    todo = @user.daily_todos.for_day(Date.current).first
    todo.update!(completed_at: Time.current)

    # parts: growth 120, binary 100, battle 100 — standard omitted → avg 107
    result = Today::DayPercent.call(user: @user)
    assert_equal 3, result.parts_count
    assert_equal 107, result.percent
  end

  test "zero items returns nil percent" do
    @user.daily_todos.for_day(Date.current).delete_all
    result = Today::DayPercent.call(user: @user)
    assert_nil result.percent
    assert_equal 0, result.parts_count
  end
end
