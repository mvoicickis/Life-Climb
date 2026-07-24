require "test_helper"

class DailyLogTest < ActiveSupport::TestCase
  test "goal from yesterday grows by at least one and about one percent" do
    assert_equal 11, Habit.goal_from_yesterday(10)
    assert_equal 41, Habit.goal_from_yesterday(40)
    assert_equal 10_100, Habit.goal_from_yesterday(10_000)
    assert_equal 1, Habit.goal_from_yesterday(0)
    assert_equal 1, Habit.goal_from_yesterday(nil)
  end

  test "empty day counts as zero and same is level" do
    habit = habits(:one)

    assert_equal BigDecimal("0"), habit.today_amount
    assert_equal BigDecimal("0"), habit.yesterday_amount
    assert_equal :level, habit.vs_yesterday
    assert_equal "Same as yesterday", habit.vs_yesterday_label
  end

  test "vs yesterday is up when today is higher" do
    habit = habits(:one)
    habit.daily_logs.create!(user: users(:one), logged_on: Date.yesterday, amount: 6, goal: 6)
    habit.daily_logs.create!(user: users(:one), logged_on: Date.current, amount: 8, goal: 7)

    assert_equal :up, habit.vs_yesterday
    assert_equal "More than yesterday", habit.vs_yesterday_label
  end

  test "vs yesterday is level when same" do
    habit = habits(:one)
    habit.daily_logs.create!(user: users(:one), logged_on: Date.yesterday, amount: 6, goal: 6)
    habit.daily_logs.create!(user: users(:one), logged_on: Date.current, amount: 6, goal: 7)

    assert_equal :level, habit.vs_yesterday
    assert_equal "Same as yesterday", habit.vs_yesterday_label
  end

  test "vs yesterday is down when lower" do
    habit = habits(:one)
    habit.daily_logs.create!(user: users(:one), logged_on: Date.yesterday, amount: 6, goal: 6)
    habit.daily_logs.create!(user: users(:one), logged_on: Date.current, amount: 4, goal: 7)

    assert_equal :down, habit.vs_yesterday
    assert_equal "Less than yesterday", habit.vs_yesterday_label
  end
end
