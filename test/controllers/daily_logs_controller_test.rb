require "test_helper"

class DailyLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @habit = habits(:one)
    seed_climb!(@user)
    sign_in_as @user
  end

  test "add mode creates today's log with posted amount" do
    @habit.daily_logs.create!(user: @user, logged_on: Date.yesterday, amount: 6, goal: 6)

    assert_difference "DailyLog.count", 1 do
      post daily_logs_path(habit_id: @habit.id), params: { mode: "add", daily_log: { amount: 8 } }
    end

    assert_redirected_to habit_path(@habit, saved: 1, won: 1)
    follow_redirect!
    assert_match(/Better than yesterday/, response.body)
    assert_equal BigDecimal("8"), @habit.reload.today_amount
  end

  test "add mode accumulates on a second log the same day" do
    post daily_logs_path(habit_id: @habit.id), params: { mode: "add", daily_log: { amount: 10 } }
    assert_equal BigDecimal("10"), @habit.reload.today_amount

    assert_no_difference "DailyLog.count" do
      post daily_logs_path(habit_id: @habit.id), params: { mode: "add", daily_log: { amount: 5 } }
    end

    assert_equal BigDecimal("15"), @habit.reload.today_amount
  end

  test "set mode replaces the day's total" do
    post daily_logs_path(habit_id: @habit.id), params: { mode: "add", daily_log: { amount: 50 } }
    post daily_logs_path(habit_id: @habit.id),
         params: { mode: "set", daily_log: { amount: 5 } }

    assert_equal BigDecimal("5"), @habit.reload.today_amount
  end

  test "set mode can clear the day to zero" do
    post daily_logs_path(habit_id: @habit.id), params: { mode: "add", daily_log: { amount: 8 } }
    post daily_logs_path(habit_id: @habit.id),
         params: { mode: "set", daily_log: { amount: 0 } }

    assert_equal BigDecimal("0"), @habit.reload.today_amount
    assert @habit.daily_logs.exists?(logged_on: Date.current, amount: 0)
  end

  test "missing mode does not replace or add to the total" do
    post daily_logs_path(habit_id: @habit.id), params: { mode: "add", daily_log: { amount: 10 } }
    assert_equal BigDecimal("10"), @habit.reload.today_amount

    post daily_logs_path(habit_id: @habit.id), params: { daily_log: { amount: 3 } }
    assert_redirected_to habit_path(@habit)
    assert_equal BigDecimal("10"), @habit.reload.today_amount
  end

  test "unrecognised mode does not replace the total" do
    post daily_logs_path(habit_id: @habit.id), params: { mode: "add", daily_log: { amount: 10 } }

    post daily_logs_path(habit_id: @habit.id),
         params: { mode: "replace", daily_log: { amount: 1 } }

    assert_equal BigDecimal("10"), @habit.reload.today_amount
  end

  test "blank or zero add does not clobber an existing total" do
    post daily_logs_path(habit_id: @habit.id), params: { mode: "add", daily_log: { amount: 10 } }

    post daily_logs_path(habit_id: @habit.id), params: { mode: "add", daily_log: { amount: "" } }
    assert_equal BigDecimal("10"), @habit.reload.today_amount

    post daily_logs_path(habit_id: @habit.id), params: { mode: "add", daily_log: { amount: "0" } }
    assert_equal BigDecimal("10"), @habit.reload.today_amount
  end

  test "undo restores the pre-add total from session not from client amount" do
    post daily_logs_path(habit_id: @habit.id),
         params: { mode: "add", return_to: "today", daily_log: { amount: 10 } }
    post daily_logs_path(habit_id: @habit.id),
         params: { mode: "add", return_to: "today", daily_log: { amount: 5 } }
    assert_equal BigDecimal("15"), @habit.reload.today_amount

    # Forged client amount must be ignored — undo uses session snapshot only.
    post daily_logs_path(habit_id: @habit.id),
         params: {
           mode: "undo",
           return_to: "today",
           daily_log: { amount: 999 }
         }

    assert_equal BigDecimal("10"), @habit.reload.today_amount
  end
end
