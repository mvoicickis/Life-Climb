# frozen_string_literal: true

require "test_helper"

class TodayBattlefieldWinStateTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    @journey = seed_climb!(@user, today_mission: "Ship auth")
    dismiss_onboarding_missions!(@user)
    @area = @journey.life_area
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    @todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Ship auth")
  end

  test "all clear shows win panel and tertiary mountain link" do
    @todo.update!(completed_at: Time.current)

    get dashboard_path
    assert_response :success

    assert_select "#today-battlefield-win", count: 1
    assert_select ".lp-today-v2-win__title"
    assert_select ".lp-today-v2-mountain-link.is-tertiary", text: I18n.t("dash.battlefield.mountain_tertiary")
    assert_select ".lp-today-v2-mountain-link.is-clear", count: 0
    assert_select ".lp-today-v2-win button", count: 0
    assert_select ".lp-today-v2-row", count: 0
  end

  test "completing last battle enqueues camp check coaching in win panel" do
    post complete_daily_todo_path(@todo), as: :turbo_stream

    assert_response :ok
    assert_match "lp-dash-project-check", response.body
    assert_match I18n.t("dash.battlefield.win_state.confirm_camp.kicker"), response.body
  end

  test "completing last battle via turbo stream swaps rows for win panel and tertiary mountain link" do
    post complete_daily_todo_path(@todo), as: :turbo_stream

    assert_response :ok
    assert_match 'target="today-battlefield-rows"', response.body
    assert_match "today-battlefield-win", response.body
    assert_match I18n.t("dash.battlefield.mountain_tertiary"), response.body
    assert_no_match I18n.t("dash.battlefield.mountain_all_clear"), response.body
    assert_no_match "is-clear", response.body
  end
end
