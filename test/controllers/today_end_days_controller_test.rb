# frozen_string_literal: true

require "test_helper"

class TodayEndDaysControllerTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
    dismiss_onboarding_missions!(@user)
    @user.habits.destroy_all
    @journey = @user.primary_focused_journey
    @todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Ship auth")
  end

  test "POST create opens day won without closing day" do
    @todo.update!(completed_at: Time.current)

    post today_end_day_path
    assert_redirected_to dashboard_path
    follow_redirect!

    assert_select ".lp-today-v2-eod-step--day-won", count: 1
    assert_select ".lp-today-v2-eod-step--closed", count: 0
    assert_select "#today-battlefield-end-day-host .lp-today-battlefield-end-day__btn", count: 0
  end

  test "POST create after save closes into sign-off" do
    @todo.update!(completed_at: Time.current)
    post today_end_day_path
    follow_redirect!

    post today_plan_tomorrow_battle_path,
         params: { title: "Tomorrow thing", schedule: "tomorrow" },
         as: :json
    assert_response :success

    get dashboard_path
    assert_select ".lp-today-v2-eod-takeover.is-closed", count: 1
    assert_select ".lp-today-v2-eod-signoff__kicker", text: /See you tomorrow/
    assert_select "button[data-action*='today-notch#shareRecap']", minimum: 1
    assert_select "a.lp-today-v2-eod-signoff__reopen", text: "Reopen day"
    assert_select "#today-battlefield-end-day-host .lp-today-battlefield-end-day__btn", count: 0
    assert_select "#today-battlefield-rows .lp-today-v2-row", count: 0
    assert_select "#today-battlefield-won-list .lp-today-v2-row", minimum: 1
  end

  test "POST create blocked when open battles remain" do
    refute @todo.completed?

    post today_end_day_path
    assert_redirected_to dashboard_path
    assert_match(/Clear every battle before you end the day/i, flash[:alert].to_s)

    follow_redirect!
    assert_select ".lp-today-v2-field", count: 1
    assert_select ".lp-today-v2-eod-step--closed", count: 0
  end

  test "DELETE destroy reopens day to day won card" do
    @todo.update!(completed_at: Time.current)
    post today_end_day_path
    follow_redirect!

    post today_plan_tomorrow_battle_path,
         params: { title: "Tomorrow thing", schedule: "tomorrow" },
         as: :json

    get dashboard_path
    assert_select ".lp-today-v2-eod-step--closed", count: 1

    delete today_end_day_path
    assert_redirected_to dashboard_path
    follow_redirect!

    assert_select ".lp-today-v2-eod-step--closed", count: 0
    assert_select ".lp-today-v2-eod-card__command", text: "Write one thing you will do tomorrow."
    assert_select ".lp-today-v2-eod-step--day-won", count: 1
    assert_select "#today-battlefield-rows .lp-today-v2-row", count: 0
  end
end
