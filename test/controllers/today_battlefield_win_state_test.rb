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
    @user.habits.destroy_all
  end

  test "all clear shows end day without ack or takeover" do
    @todo.update!(completed_at: Time.current)

    get dashboard_path
    assert_response :success

    assert_select "#today-battlefield-win", count: 0
    assert_select ".lp-today-v2-eod-ack", count: 0
    assert_select "#today-end-of-day", count: 0
    assert_select "#today-battlefield-end-day-host .lp-today-battlefield-end-day__btn", count: 1
    assert_select "#today-battlefield-rows .lp-today-v2-row", count: 0
    assert_select "#today-battlefield-won-list .lp-today-v2-row", count: 1
  end

  test "completing last battle does not show takeover until end day" do
    post complete_daily_todo_path(@todo), as: :turbo_stream

    assert_response :ok
    assert_no_match "lp-today-v2-eod-step--day-won", response.body
    assert_no_match 'id="today-end-of-day"', response.body
    assert_no_match "lp-dash-project-check", response.body
    assert_no_match "today-battlefield-win", response.body
    assert_match "today-battlefield-end-day-host", response.body
  end

  test "completing last battle via turbo stream keeps won shell without ack" do
    post complete_daily_todo_path(@todo), as: :turbo_stream

    assert_response :ok
    assert_match %(target="#{dom_id(@todo, :battlefield_row)}"), response.body
    assert_match "is-pending-won", response.body
    assert_match "today-battlefield-won-shell", response.body
    assert_no_match "today-eod-ack-host", response.body
    assert_no_match I18n.t("dash.end_of_day.ack.all_battles_won", count: 1), response.body
    assert_no_match I18n.t("dash.battlefield.mountain_all_clear"), response.body
    assert_no_match %(turbo-stream action="replace" target="today-battlefield-body"), response.body
    assert_no_match "is-clear", response.body
  end
end
