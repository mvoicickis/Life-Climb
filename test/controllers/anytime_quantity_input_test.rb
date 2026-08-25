# frozen_string_literal: true

require "test_helper"

class AnytimeQuantityInputTest < ActionDispatch::IntegrationTest
  setup { enable_habits! }
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
    dismiss_onboarding_missions!(@user)
    @user.habits.destroy_all
    @habit = @user.habits.create!(
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
  end

  test "growth quantity habit quick-add values remain available off Today UI" do
    get dashboard_path
    assert_response :success

    assert_equal 5, @habit.quick_add_value
    assert_equal [ 5, 10, 25, 50 ], @habit.quick_add_suggestions
    assert_select ".lp-dash-anytime", count: 0
    assert_select "#today_habit_#{@habit.id}", count: 0
  end

  test "habit overflow menu is absent from Today V2 battlefield" do
    get dashboard_path
    assert_response :success

    assert_select ".lp-dash-anytime", count: 0
    assert_select "#today_habit_#{@habit.id}", count: 0

    post daily_logs_path(habit_id: @habit.id),
         params: { mode: "add", return_to: "today", daily_log: { amount: "5" } }
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success
    assert_select "#today_habit_#{@habit.id}", count: 0
  end

  test "chip PATCH turbo stream updates sheet and card button without redirect" do
    patch habit_path(@habit),
          params: {
            return_to: "today",
            quick_add_sheet: "1",
            habit: { quick_add_amount: 10 }
          },
          as: :turbo_stream

    assert_response :success
    assert_equal Mime[:turbo_stream].to_s, response.media_type
    assert_nil response.redirect_url
    assert_equal 10, @habit.reload.quick_add_amount

    assert_match(/turbo-stream[^>]*target="#{dom_id(@habit, :today_quick)}"/, response.body)
    assert_match(/turbo-stream[^>]*target="#{dom_id(@habit, :today_sheet)}"/, response.body)
    assert_includes response.body, "Add 10 reps"
    assert_includes response.body, "+10"
    assert_match(/lp-dash-habit__chip is-on/, response.body)
  end

  test "HTML chip PATCH still persists and redirects to Today" do
    patch habit_path(@habit),
          params: {
            return_to: "today",
            quick_add_sheet: "1",
            habit: { quick_add_amount: 25 }
          }
    assert_redirected_to dashboard_path
    assert_equal 25, @habit.reload.quick_add_amount
  end

  test "custom amount Use PATCH turbo stream persists and stays on the stream" do
    patch habit_path(@habit),
          params: {
            return_to: "today",
            quick_add_sheet: "1",
            habit: { quick_add_amount: 7 }
          },
          as: :turbo_stream

    assert_response :success
    assert_equal Mime[:turbo_stream].to_s, response.media_type
    assert_equal 7, @habit.reload.quick_add_amount
    assert_includes response.body, "Add 7 reps"
    assert_no_match(/lp-dash-habit__chip is-on/, response.body)
  end

  test "standard quantity habit quick-add values remain available off Today UI" do
    @habit.update!(stat_type: "standard", goal: nil, min_value: 10, max_value: 20)
    get dashboard_path
    assert_response :success

    assert_equal 5, @habit.quick_add_value
    assert_select "#today_habit_#{@habit.id}", count: 0
  end

  test "unlogged quantity habit has no Today card markup on battlefield UI" do
    get dashboard_path
    assert_response :success
    assert_select "#today_habit_#{@habit.id}", count: 0
    assert_select ".lp-dash-anytime", count: 0
  end

  test "logged quantity habit has no Today card markup on battlefield UI" do
    @habit.daily_logs.create!(user: @user, logged_on: Date.current, amount: 7, goal: 25)
    get dashboard_path
    assert_response :success
    assert_select "#today_habit_#{@habit.id}", count: 0
    assert_equal 7, @habit.reload.today_amount.to_i
  end

  test "plus form posts mode add only via daily_logs endpoint" do
    post daily_logs_path(habit_id: @habit.id),
         params: { mode: "add", return_to: "today", daily_log: { amount: "5" } }
    assert_redirected_to dashboard_path
    assert_equal 5, @habit.reload.today_amount.to_i
  end

  test "failed today add shows unmistakable alert after optimistic pop path" do
    post daily_logs_path(habit_id: @habit.id),
         params: {
           mode: "add",
           return_to: "today",
           daily_log: { amount: "" }
         }
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success
    assert_select ".lp-flash--alert[role=alert][data-lp-log-failed=true]",
                  text: /That log didn’t save/
    assert_match(/Enter how many to add/, response.body)
  end
end
