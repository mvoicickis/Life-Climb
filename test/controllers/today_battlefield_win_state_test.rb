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

  test "all clear shows inline battle ack and step 1 win takeover" do
    @todo.update!(completed_at: Time.current)

    get dashboard_path
    assert_response :success

    assert_select "#today-battlefield-win", count: 0
    assert_select ".lp-today-v2-inline-ack", text: /All battles won today/
    assert_select "#today-end-of-day", count: 1
    assert_select ".lp-today-v2-eod-win__title", text: "You cleared the field"
    assert_select ".lp-today-v2-eod-win__stats", text: /You won 1 of 1 battles/
    assert_select ".lp-today-v2-mountain-link.is-tertiary", text: I18n.t("dash.battlefield.mountain_tertiary")
    assert_select ".lp-today-v2-row", count: 0
  end

  test "completing last battle enqueues camp check below end-of-day bridge" do
    post complete_daily_todo_path(@todo), as: :turbo_stream

    assert_response :ok
    assert_match "lp-dash-project-check", response.body
    assert_match "today-end-of-day", response.body
    assert_match I18n.t("dash.end_of_day.inline_ack.battles"), response.body
    assert_no_match "today-battlefield-win", response.body
  end

  test "completing last battle via turbo stream swaps rows for inline ack and end-of-day host" do
    post complete_daily_todo_path(@todo), as: :turbo_stream

    assert_response :ok
    assert_match 'id="today-battlefield-body"', response.body
    assert_match "today-end-of-day-host", response.body
    assert_match I18n.t("dash.end_of_day.inline_ack.battles"), response.body
    assert_match "lp-today-v2-eod-win", response.body
    assert_match I18n.t("dash.battlefield.mountain_tertiary"), response.body
    assert_no_match I18n.t("dash.battlefield.mountain_all_clear"), response.body
    assert_no_match "is-clear", response.body
  end
end
