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

  test "risk hint only before first ever battle win" do
    @user.daily_todos.update_all(completed_at: nil)
    refute @user.battle_won_once?

    get dashboard_path
    assert_response :success
    assert_select ".lp-today-v2-risk", text: I18n.t("dash.battlefield.risk_before_first_win")

    post complete_daily_todo_path(@todo), as: :turbo_stream
    assert_response :ok
    assert @user.reload.battle_won_once?

    get dashboard_path
    assert_response :success
    assert_select ".lp-today-v2-risk", count: 0
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
