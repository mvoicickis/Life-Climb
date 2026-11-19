# frozen_string_literal: true

require "test_helper"

class TodayV2LookTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
    dismiss_onboarding_missions!(@user)
    @todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Ship auth")
  end

  test "today photo background and frosted group cards render" do
    get dashboard_path
    assert_response :success

    assert_select ".lp-dash.is-today-photo", count: 1
    assert_select "img.lp-today-photo-bg__img[src*='today_background']", count: 1
    assert_select ".lp-today-group-card", minimum: 2
    assert_select ".lp-today-v2-header--compact", count: 1
    assert_select ".lp-today-v2-header__avatar", count: 0
  end

  test "battle count hidden at zero done" do
    get dashboard_path
    assert_response :success

    assert_select "#today-battlefield-count[hidden]", count: 1

    post complete_daily_todo_path(@todo), as: :turbo_stream
    assert_response :ok
    assert_select "#today-battlefield-count", count: 1
    assert_select "#today-battlefield-count[hidden]", count: 0
  end

  test "goal card shows camp bar and reveals won after first battle win" do
    @user.daily_todos.update_all(completed_at: nil)
    journey = @user.primary_focused_journey
    camp = Strategy::PathProject.resolve(user: @user, journey: journey)
    assert camp.present?
    # Keep a second open battle so winning one does not finish the camp.
    camp.children.create!(
      user: @user,
      life_area: journey.life_area,
      life_journey: journey,
      horizon: "day",
      title: "Next fight",
      scheduled_on: Date.current + 1.day,
      position: 1
    )

    get dashboard_path
    assert_response :success
    assert_select "#today-battlefield-header .lp-today-goal-camp", text: camp.title
    assert_select "#today-battlefield-header .lp-today-camp-bar", count: 1
    assert_select "#today-battlefield-header .lp-today-camp-bar__fill[style*='--lp-fill: 0.0']", count: 1
    assert_select "#today-battlefield-header .lp-today-camp-won[hidden]", count: 1
    assert_select "#today-battlefield-header .lp-today-v2-risk", count: 0

    post complete_daily_todo_path(@todo), as: :turbo_stream
    assert_response :ok
    assert_match %(target="today-battlefield-header"), response.body
    assert_match(/lp-today-camp-bar__fill[^>]*--lp-fill: 0\.5/, response.body)
    assert_match(/lp-today-camp-won(?![^>]*\bhidden\b)/, response.body)

    get dashboard_path
    assert_response :success
    assert_select "#today-battlefield-header .lp-today-goal-camp", text: camp.title
    assert_select "#today-battlefield-header .lp-today-camp-bar__fill[style*='--lp-fill: 0.5']", count: 1
    assert_select "#today-battlefield-header .lp-today-camp-won:not([hidden])", count: 1
    assert_match(/\b1\b/, css_select("#today-battlefield-header .lp-today-camp-won").text)
    assert_select "#today-battlefield-header .lp-today-v2-risk", count: 0
  end

  test "inline add row replaces mountain add link" do
    get dashboard_path
    assert_response :success

    assert_select "#today-battlefield-add-host .lp-today-add-battle", count: 1
    assert_select "a.lp-today-v2-mountain-link.is-add-on-mountain", count: 0
  end

  test "quantity basic hides unit meta at zero" do
    enable_habits!
    @user.habits.destroy_all
    habit = @user.habits.create!(
      name: "Study PDC",
      unit: "pages",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      quantity_checkin: true
    )

    get dashboard_path
    assert_response :success

    assert_select "#today_habit_#{habit.id}.is-quantity", count: 1
    assert_select "#today_habit_#{habit.id} .lp-dash-tcard__meta", text: /pages/, count: 0
  end

  test "quantity basic shows unit meta above zero" do
    enable_habits!
    @user.habits.destroy_all
    habit = @user.habits.create!(
      name: "Study PDC",
      unit: "pages",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      quantity_checkin: true
    )
    habit.daily_logs.create!(user: @user, logged_on: Date.current, amount: 3)

    get dashboard_path
    assert_response :success

    assert_select "#today_habit_#{habit.id} .lp-dash-tcard__meta", text: /3 pages/
  end

  test "basics count hidden when none done" do
    enable_habits!
    @user.habits.destroy_all
    @user.habits.create!(
      name: "Water", unit: "glasses", points: 5, frequency: "daily",
      active: true, show_on_home: true, quantity_checkin: false
    )

    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-anytime__count[hidden]", count: 1
  end
end
