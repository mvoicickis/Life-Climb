# frozen_string_literal: true

require "test_helper"

class DailyLogsTodayStreamTest < ActionDispatch::IntegrationTest
  setup { enable_habits! }
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
    dismiss_onboarding_missions!(@user)
    @user.habits.active.on_home.destroy_all
    @habit = @user.habits.create!(
      name: "Push-Ups",
      unit: "reps",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "growth",
      goal: 25,
      quantity_checkin: true,
      quick_add_amount: 5
    )
  end

  test "set mode turbo stream replaces sheet row fragments and basics count" do
    post daily_logs_path(habit_id: @habit.id),
         params: {
           mode: "set",
           return_to: "today",
           daily_log: { amount: 12 }
         },
         as: :turbo_stream

    assert_response :success
    assert_equal Mime[:turbo_stream].to_s, response.media_type
    assert_equal BigDecimal("12"), @habit.reload.today_amount

    assert_match(/turbo-stream[^>]*target="#{dom_id(@habit, :today_sheet)}"/, response.body)
    assert_match(/turbo-stream[^>]*target="#{dom_id(@habit, :today_meta)}"/, response.body)
    assert_match(/turbo-stream[^>]*target="#{dom_id(@habit, :today_quick)}"/, response.body)
    assert_match(/turbo-stream[^>]*target="#{dom_id(@habit, :today_segs)}"/, response.body)
    assert_match(/turbo-stream[^>]*target="#{dom_id(:basics, :survived_count)}"/, response.body)
    assert_includes response.body, "basic-sheet-log"
    assert_match(/12/, response.body)
  end

  test "set mode turbo stream failure returns 422 without changing amount" do
    @habit.daily_logs.create!(user: @user, logged_on: Date.current, amount: 8, goal: 25)

    post daily_logs_path(habit_id: @habit.id),
         params: {
           mode: "set",
           return_to: "today",
           daily_log: { amount: -3 }
         },
         as: :turbo_stream

    assert_response :unprocessable_entity
    assert_equal BigDecimal("8"), @habit.reload.today_amount
  end

  test "set to goal then below then goal again awards rhythm points once" do
    goal = @habit.goal
    rhythm_scope = -> { @user.life_point_ledgers.where(source: @habit) }

    assert_difference -> { rhythm_scope.call.count }, 1 do
      post daily_logs_path(habit_id: @habit.id),
           params: { mode: "set", return_to: "today", daily_log: { amount: goal } },
           as: :turbo_stream
      assert_response :success
    end

    assert_no_difference -> { rhythm_scope.call.count } do
      post daily_logs_path(habit_id: @habit.id),
           params: { mode: "set", return_to: "today", daily_log: { amount: 1 } },
           as: :turbo_stream
      assert_response :success
    end

    assert_no_difference -> { rhythm_scope.call.count } do
      post daily_logs_path(habit_id: @habit.id),
           params: { mode: "set", return_to: "today", daily_log: { amount: goal } },
           as: :turbo_stream
      assert_response :success
    end

    assert_equal 1, rhythm_scope.call.count
    assert_equal LifePointsAward::RHYTHM, rhythm_scope.call.sum(:amount)
  end

  test "html set still redirects to dashboard" do
    post daily_logs_path(habit_id: @habit.id),
         params: { mode: "set", return_to: "today", daily_log: { amount: 3 } }

    assert_redirected_to dashboard_path
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password12345" }
  end
end
