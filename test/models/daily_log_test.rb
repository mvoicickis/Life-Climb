require "test_helper"

class HabitStatusEvaluatorTest < ActiveSupport::TestCase
  test "better than yesterday compares higher equal and lower" do
    habit = habits(:one)
    habit.update!(stat_type: "growth", goal: nil)
    habit.daily_logs.create!(user: users(:one), logged_on: Date.yesterday, amount: 20)
    habit.daily_logs.create!(user: users(:one), logged_on: Date.current, amount: 25)

    assert_equal :better, habit.status
    assert_equal "Better than yesterday", habit.status_label

    habit.daily_logs.find_by!(logged_on: Date.current).update!(amount: 20)
    assert_equal :same, habit.reload.status

    habit.daily_logs.find_by!(logged_on: Date.current).update!(amount: 10)
    assert_equal :worse, habit.reload.status
  end

  test "healthy range perfect too low and too high" do
    habit = habits(:one)
    habit.update!(stat_type: "standard", min_value: 8, max_value: 9, goal: nil)
    log = habit.daily_logs.create!(user: users(:one), logged_on: Date.current, amount: 8.5)

    assert_equal :perfect, habit.status
    assert_equal "Within healthy range", habit.status_label

    log.update!(amount: 6.5)
    assert_equal :too_low, habit.reload.status

    log.update!(amount: 10)
    assert_equal :too_high, habit.reload.status
  end

  test "healthy range allows max-only screen time style goals" do
    habit = habits(:one)
    habit.update!(stat_type: "standard", min_value: nil, max_value: 2, goal: nil)
    habit.daily_logs.create!(user: users(:one), logged_on: Date.current, amount: 1)

    assert_equal :perfect, habit.status

    habit.daily_logs.find_by!(logged_on: Date.current).update!(amount: 3)
    assert_equal :too_high, habit.reload.status
  end

  test "goal raise prompt only when growth goal is set and hit" do
    habit = habits(:one)
    habit.update!(stat_type: "growth", goal: 10)
    habit.daily_logs.create!(user: users(:one), logged_on: Date.current, amount: 10)

    assert habit.show_goal_raise_prompt?
    habit.decline_goal_raise!
    assert_not habit.show_goal_raise_prompt?
  end
end

class DailyLogTest < ActiveSupport::TestCase
  test "goal from yesterday grows by at least one and about one percent" do
    assert_equal 11, Habit.goal_from_yesterday(10)
    assert_equal 41, Habit.goal_from_yesterday(40)
    assert_equal 10_100, Habit.goal_from_yesterday(10_000)
    assert_equal 1, Habit.goal_from_yesterday(0)
    assert_equal 1, Habit.goal_from_yesterday(nil)
  end

  test "empty growth day counts as zero and same" do
    habit = habits(:one)

    assert_equal BigDecimal("0"), habit.today_amount
    assert_equal BigDecimal("0"), habit.yesterday_amount
    assert_equal :same, habit.status
  end
end
