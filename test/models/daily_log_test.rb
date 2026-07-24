require "test_helper"

class DailyLogTest < ActiveSupport::TestCase
  test "goal from yesterday grows by at least one and about one percent" do
    assert_equal 11, Habit.goal_from_yesterday(10)
    assert_equal 41, Habit.goal_from_yesterday(40)
    assert_equal 10_100, Habit.goal_from_yesterday(10_000)
    assert_equal 1, Habit.goal_from_yesterday(0)
    assert_equal 1, Habit.goal_from_yesterday(nil)
  end

  test "empty growth day counts as zero and same is level" do
    habit = habits(:one)

    assert_equal BigDecimal("0"), habit.today_amount
    assert_equal BigDecimal("0"), habit.yesterday_amount
    assert_equal :level, habit.status
    assert_equal "Same as yesterday", habit.status_label
  end

  test "growth status is up when today is higher" do
    habit = habits(:one)
    habit.daily_logs.create!(user: users(:one), logged_on: Date.yesterday, amount: 6, goal: 6)
    habit.daily_logs.create!(user: users(:one), logged_on: Date.current, amount: 8, goal: 7)

    assert_equal :up, habit.status
  end

  test "growth status is level when same for under three days" do
    habit = habits(:one)
    habit.daily_logs.create!(user: users(:one), logged_on: Date.yesterday, amount: 6, goal: 6)
    habit.daily_logs.create!(user: users(:one), logged_on: Date.current, amount: 6, goal: 7)

    assert_equal :level, habit.status
  end

  test "growth status is down when lower" do
    habit = habits(:one)
    habit.daily_logs.create!(user: users(:one), logged_on: Date.yesterday, amount: 6, goal: 6)
    habit.daily_logs.create!(user: users(:one), logged_on: Date.current, amount: 4, goal: 7)

    assert_equal :down, habit.status
  end

  test "growth level decays to down after three level days" do
    habit = habits(:one)
    user = users(:one)
    # Three consecutive days with the same amount → third day decays to Down
    habit.daily_logs.create!(user: user, logged_on: Date.current - 3, amount: 5, goal: 5)
    habit.daily_logs.create!(user: user, logged_on: Date.current - 2, amount: 5, goal: 5)
    habit.daily_logs.create!(user: user, logged_on: Date.current - 1, amount: 5, goal: 5)
    habit.daily_logs.create!(user: user, logged_on: Date.current, amount: 5, goal: 5)

    assert_equal :down, habit.status
    assert_match(/counts as Down/, habit.status_label)
  end

  test "standard ok when within min and optional max" do
    habit = habits(:one)
    habit.update!(stat_type: "standard", min_value: 7, max_value: 9, goal: nil)
    habit.daily_logs.create!(user: users(:one), logged_on: Date.current, amount: 8)

    assert_equal :ok, habit.status
  end

  test "standard off when below min or above max" do
    habit = habits(:one)
    habit.update!(stat_type: "standard", min_value: 7000, max_value: nil, goal: nil)
    habit.daily_logs.create!(user: users(:one), logged_on: Date.current, amount: 5000)
    assert_equal :off, habit.status

    habit.daily_logs.find_by!(logged_on: Date.current).update!(amount: 8000)
    assert_equal :ok, habit.reload.status

    habit.update!(max_value: 7500)
    assert_equal :off, habit.status
  end

  test "goal raise prompt only when growth goal is set and hit" do
    habit = habits(:one)
    habit.update!(goal: 10)
    habit.daily_logs.create!(user: users(:one), logged_on: Date.current, amount: 10)

    assert habit.show_goal_raise_prompt?

    habit.decline_goal_raise!
    assert_not habit.show_goal_raise_prompt?

    habit.update!(goal_raise_declined_on: nil)
    habit.raise_goal!
    assert_equal BigDecimal("11"), habit.goal
  end

  test "no goal raise prompt when growth has no goal" do
    habit = habits(:one)
    habit.update!(goal: nil)
    habit.daily_logs.create!(user: users(:one), logged_on: Date.current, amount: 99)

    assert_not habit.show_goal_raise_prompt?
  end
end
