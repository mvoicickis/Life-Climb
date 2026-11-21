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

  test "today photo background frosted cards and top bar render" do
    get dashboard_path
    assert_response :success

    assert_select ".lp-dash.is-today-photo", count: 1
    assert_select "img.lp-today-photo-bg__img[src*='today_background']", count: 1
    assert_select ".lp-today-group-card", minimum: 2
    assert_select ".lp-today-v2-header--compact", count: 1
    assert_select "#today-top-bar.lp-today-top", count: 1
    assert_select "#today-top-bar .lp-avatar-circle, #today-top-bar .lp-avatar-circle--initial", minimum: 1
    assert_select "#today-top-bar .lp-today-top__hi", minimum: 1
    assert_select "#today-top-bar .lp-today-top__date", minimum: 1
    assert_select ".lp-today-v2-header__avatar", count: 0
    assert_select "#today-battlefield-header .lp-other-mountains-button", count: 0
    assert_select ".lp-today-scroll__pad", count: 1
    assert_select "#today-dash-nav .lp-dash-nav.is-v4", count: 1
  end

  test "battle rows have no camp label and use 3d tick markup" do
    get dashboard_path
    assert_response :success

    assert_select "#today-battlefield-field .lp-today-v2-field__title", text: "Battles"
    assert_no_match(/Today's battlefield/, response.body)
    assert_no_match(/⚔/, css_select("#today-battlefield-field .lp-today-v2-field__title").text)
    assert_select "#today-battlefield-rows .lp-today-v2-row__title", minimum: 1
    assert_select "#today-battlefield-rows .lp-today-v2-row__camp", count: 0
    assert_select "#today-battlefield-rows .lp-today-v2-row__camp-inline", count: 0
    assert_select "#today-battlefield-rows .lp-today-v2-row__box", minimum: 1
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
    assert_select "#today-battlefield-header .lp-today-goal-strip", count: 1
    assert_select "#today-battlefield-header .lp-today-goal-camp", count: 0
    assert_select "#today-battlefield-header .lp-today-camp-of", count: 0
    assert_select "#today-battlefield-header .lp-today-camp-bar[aria-valuetext]", count: 1
    assert_select "#today-battlefield-header .lp-today-camp-bar", count: 1
    assert_select "#today-battlefield-header .lp-today-camp-bar__fill[style*='--lp-fill: 0.0']", count: 1
    assert_select "#today-battlefield-header .lp-today-v2-risk", count: 0

    post complete_daily_todo_path(@todo), as: :turbo_stream
    assert_response :ok
    assert_match %(target="today-battlefield-header"), response.body
    assert_match(/lp-today-camp-bar__fill[^>]*--lp-fill: 0\.5/, response.body)

    get dashboard_path
    assert_response :success
    assert_select "#today-battlefield-header .lp-today-camp-bar__fill[style*='--lp-fill: 0.5']", count: 1
    assert_select "#today-battlefield-header .lp-today-v2-risk", count: 0
  end

  test "inline add row replaces mountain add link" do
    get dashboard_path
    assert_response :success

    assert_select "#today-battlefield-add-host .lp-today-add-battle", count: 1
    assert_select "#today-battlefield-add-host .lp-today-add-battle__expand", count: 1
    assert_select "#today-battlefield-add-host [data-action*='blur->today-add-battle#blurField']", count: 1
    assert_select "a.lp-today-v2-mountain-link.is-add-on-mountain", count: 0
  end

  test "Today uses one SVG chevron for Habits and Won today" do
    enable_habits!
    @user.habits.destroy_all
    @user.habits.create!(
      name: "Water", unit: "cups", points: 5, frequency: "daily",
      active: true, show_on_home: true, quantity_checkin: true, goal: 8
    )
    post complete_daily_todo_path(@todo), as: :turbo_stream

    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-anytime__chev.lp-chevron", count: 1
    assert_select "#today-battlefield-won-shell .lp-today-v2-won__chev.lp-chevron", count: 1
    assert_no_match(/[▾›◂]/, css_select(".lp-dash-anytime__chev, .lp-today-v2-won__chev").text)
  end

  test "quantity basic shows goal until logged then amount" do
    enable_habits!
    @user.habits.destroy_all
    habit = @user.habits.create!(
      name: "Water",
      unit: "cups",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      quantity_checkin: true,
      goal: 8
    )

    get dashboard_path
    assert_response :success

    assert_select "#today_habit_#{habit.id}.is-quantity", count: 1
    assert_select "#today_habit_#{habit.id} .lp-dash-tcard__meta", text: /8 cups/
    assert_select "#today_habit_#{habit.id} .lp-dash-tcard__meta", text: /0 of/, count: 0

    habit.daily_logs.create!(user: @user, logged_on: Date.current, amount: 3)
    get dashboard_path
    assert_response :success
    assert_select "#today_habit_#{habit.id} .lp-dash-tcard__meta", text: /3 of 8 cups/
  end

  test "habits card is collapsed by default and keeps count host" do
    enable_habits!
    @user.habits.destroy_all
    @user.habits.create!(
      name: "Water", unit: "glasses", points: 5, frequency: "daily",
      active: true, show_on_home: true, quantity_checkin: false
    )

    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-anytime[data-controller~='today-habits']", count: 1
    assert_select ".lp-dash-anytime__body[hidden]", count: 1
    assert_select "#basics_collapsed_title", text: "Habits"
    assert_select "#basics_survived_count", count: 1
    assert_no_match(%r{Habits · 0}, response.body)
    assert_no_match(%r{0/\d+}, css_select("#basics_survived_count").text)
  end

  test "all won line and won fold stay inside battles card" do
    post complete_daily_todo_path(@todo), as: :turbo_stream
    assert_response :ok

    get dashboard_path
    assert_response :success
    assert_select "#today-battlefield-field .lp-today-all-clear", count: 0
    assert_select "#today-battlefield-all-clear-line", count: 1
    assert_select "#today-battlefield-field #today-battlefield-won-shell", count: 1
    assert_select "#today-battlefield-won-list .lp-today-v2-row", minimum: 1
  end
end
