require "test_helper"

class DailyLogsControllerTest < ActionDispatch::IntegrationTest
  test "save today amount and compare to yesterday" do
    user = users(:one)
    habit = habits(:one)
    sign_in_as user

    habit.daily_logs.create!(user: user, logged_on: Date.yesterday, amount: 6, goal: 6)

    assert_difference "DailyLog.count", 1 do
      post daily_logs_path(habit_id: habit.id), params: { daily_log: { amount: 8 } }
    end

    assert_redirected_to habit_path(habit, saved: 1, won: 1)
    follow_redirect!
    assert_match(/More than yesterday/, response.body)
    assert_equal BigDecimal("8"), habit.reload.today_amount
  end

  test "blank amount becomes zero" do
    user = users(:one)
    habit = habits(:one)
    sign_in_as user

    post daily_logs_path(habit_id: habit.id), params: { daily_log: { amount: "" } }
    assert_equal BigDecimal("0"), habit.reload.today_amount
  end
end
