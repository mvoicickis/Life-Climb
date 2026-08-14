# frozen_string_literal: true

require "test_helper"

class AnytimeQuantityInputTest < ActionDispatch::IntegrationTest
  setup { enable_habits! }
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
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

  test "growth quantity habit shows one derived quick-add and exact amount in menu" do
    get dashboard_path
    assert_response :success

    assert_equal 5, @habit.quick_add_value
    assert_equal [ 5, 10, 25, 50 ], @habit.quick_add_suggestions
    assert_select "#today_habit_#{@habit.id} .lp-dash-habit__qb.is-big", count: 1
    assert_select "#today_habit_#{@habit.id} button[aria-label=?]", "Add 5 reps"
    assert_select "#today_habit_#{@habit.id} .lp-dash-habit__segs i", count: 16
    assert_select "#today_habit_#{@habit.id} .lp-dash-habit__sig", count: 2
    assert_select "#today_habit_#{@habit.id} .lp-dash-habit__act .lp-dash-habit__qb.is-big", count: 1
    assert_select "#today_habit_#{@habit.id} .lp-dash-habit__r2", count: 0
    assert_select "#today_habit_#{@habit.id} .lp-dash-habit__quick", count: 0

    assert_select "#today_habit_#{@habit.id} form.lp-dash-tcard__qty .lp-dash-tcard__amount", count: 1
    assert_select "#today_habit_#{@habit.id} form.lp-dash-tcard__qty", count: 1
    assert_select "#today_habit_#{@habit.id} form[action=?]",
                  completions_path(habit_id: @habit.id),
                  count: 0
  end

  # Regression: #311 moved exact/set/undo into a ⋯ sheet. Assert the menu shell +
  # chips, custom Use, and quieter exact/set (undo when a session snapshot exists).
  test "habit overflow menu renders chips, exact amount, set total, and undo when applicable" do
    get dashboard_path
    assert_response :success

    card = "#today_habit_#{@habit.id}"
    assert_select "#{card}[data-controller~=tcard-menu]", count: 1
    assert_select "#{card} details.lp-dash-habit__menu[data-tcard-menu-target=details]", count: 1
    assert_select "#{card} summary.lp-dash-habit__dots", count: 1
    assert_select "#{card} .lp-dash-habit__sheet", count: 1
    assert_select "#{card} .lp-dash-habit__grab", count: 1
    assert_select "#{card} .lp-dash-habit__chip", count: 4
    assert_select "#{card} .lp-dash-habit__chip.is-on", text: "+5"
    assert_select "#{card} .lp-dash-habit__chip[aria-pressed=true]", count: 1
    assert_select "#{card} .lp-dash-habit__custom-input", count: 1
    assert_select "#{card} .lp-dash-habit__use", count: 1

    assert_select "#{card} .lp-dash-habit__sheet-label", text: /Enter exact amount/
    assert_select "#{card} form.lp-dash-habit__exact-form.lp-dash-tcard__qty", count: 1
    assert_select "#{card} form.lp-dash-habit__exact-form input[name=mode][value=add]", count: 1
    assert_select "#{card} form.lp-dash-habit__exact-form .lp-dash-tcard__amount", count: 1

    assert_select "#{card} .lp-dash-habit__sheet-label", text: /Set total/
    assert_select "#{card} form.lp-dash-habit__set-form", count: 1
    assert_select "#{card} form.lp-dash-habit__set-form input[name=mode][value=set]", count: 1
    assert_select "#{card} form.lp-dash-habit__set-form .lp-dash-tcard__amount", count: 1
    assert_select "#{card} .lp-dash-habit__sheet-steps", count: 0
    assert_select "#{card} .lp-dash-habit__sheet-btn.is-undo", count: 0

    post daily_logs_path(habit_id: @habit.id),
         params: { mode: "add", return_to: "today", daily_log: { amount: "5" } }
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success

    assert_select "#{card} .lp-dash-habit__sheet-btn.is-undo", text: /Undo/
    assert_select "#{card} form.lp-dash-habit__exact-form", count: 1
    assert_select "#{card} form.lp-dash-habit__set-form", count: 1
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

  test "standard quantity habit shows a single derived quick-add from the range" do
    @habit.update!(stat_type: "standard", goal: nil, min_value: 10, max_value: 20)
    get dashboard_path
    assert_response :success

    assert_equal 5, @habit.quick_add_value
    assert_select "#today_habit_#{@habit.id} .lp-dash-habit__qb.is-big", count: 1
    assert_select "#today_habit_#{@habit.id} button[aria-label=?]", "Add 5 reps"
    assert_select "#today_habit_#{@habit.id} .lp-dash-habit__act .lp-dash-habit__qb", count: 1
    assert_select "#today_habit_#{@habit.id} .lp-dash-habit__chip", count: 4
  end

  test "unlogged quantity habit renders blank required amount input with mode add" do
    get dashboard_path
    assert_response :success

    input = css_select("#today_habit_#{@habit.id} form.lp-dash-tcard__qty .lp-dash-tcard__amount").first
    assert input
    assert_equal "required", input["required"]
    value = input["value"].to_s
    assert value.blank? || value == "", "expected blank value, got #{value.inspect}"
    assert_select "#today_habit_#{@habit.id} form.lp-dash-tcard__qty input[name=mode][value=add]", count: 1
    assert_select "#today_habit_#{@habit.id} form.lp-dash-tcard__qty input[name=mode][value=set]", count: 0
  end

  test "logged quantity habit keeps add input blank and shows running total in meta" do
    @habit.daily_logs.create!(user: @user, logged_on: Date.current, amount: 7, goal: 25)
    get dashboard_path
    assert_response :success

    input = css_select("#today_habit_#{@habit.id} form.lp-dash-tcard__qty .lp-dash-tcard__amount").first
    assert input
    value = input["value"].to_s
    assert value.blank? || value == "", "expected blank add field, got #{value.inspect}"
    assert_match(/7 of 25/, response.body)
    assert_select "#today_habit_#{@habit.id} .lp-dash-habit__pct", text: "28%"
  end

  test "plus form posts mode add only" do
    get dashboard_path
    assert_response :success
    assert_select "#today_habit_#{@habit.id} #today_quick_habit_#{@habit.id} input[name=mode][value=add]", count: 1
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
