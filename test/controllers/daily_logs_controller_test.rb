require "test_helper"

class DailyLogsControllerTest < ActionDispatch::IntegrationTest
  test "save today amount and compare to yesterday" do
    user = users(:one)
    habit = habits(:one)
    seed_climb!(user)
    sign_in_as user

    habit.daily_logs.create!(user: user, logged_on: Date.yesterday, amount: 6, goal: 6)

    assert_difference "DailyLog.count", 1 do
      post daily_logs_path(habit_id: habit.id), params: { daily_log: { amount: 8 } }
    end

    assert_redirected_to habit_path(habit, saved: 1, won: 1)
    follow_redirect!
    assert_match(/Better than yesterday/, response.body)
    assert_equal BigDecimal("8"), habit.reload.today_amount
  end

  test "blank amount still coerces to zero if posted without HTML required" do
    user = users(:one)
    habit = habits(:one)
    seed_climb!(user)
    sign_in_as user

    post daily_logs_path(habit_id: habit.id), params: { daily_log: { amount: "" } }
    assert_equal BigDecimal("0"), habit.reload.today_amount
  end

  test "explicit zero amount saves normally" do
    user = users(:one)
    habit = habits(:one)
    seed_climb!(user)
    sign_in_as user

    post daily_logs_path(habit_id: habit.id), params: { daily_log: { amount: "0" } }
    assert_equal BigDecimal("0"), habit.reload.today_amount
    assert habit.daily_logs.exists?(logged_on: Date.current, amount: 0)
  end
end
