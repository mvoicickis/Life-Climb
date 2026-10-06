# frozen_string_literal: true

require "test_helper"

class TodayLegacyEodSessionTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
    dismiss_onboarding_missions!(@user)
    @todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Ship auth")
    @todo.update!(completed_at: Time.current)
  end

  test "legacy end day and sign-off session keys do not render end of day UI" do
    post today_end_day_path
    follow_redirect!

    post today_plan_tomorrow_battle_path,
         params: { title: "Tomorrow thing", schedule: "tomorrow" },
         as: :json
    assert_response :success

    get dashboard_path
    assert_response :success

    assert_select "#today-end-of-day", count: 0
    assert_select ".lp-today-v2-eod-step--day-won", count: 0
    assert_select ".lp-today-v2-eod-step--closed", count: 0
    assert_select ".lp-today-battlefield-end-day__btn", count: 0
    assert_select "#today-battlefield-end-day-host .lp-today-empty-cta__pill", count: 1
    assert_select "#today-battlefield-won-list .lp-today-v2-row", minimum: 1
  end

  test "legacy eod acknowledge session alone does not show takeover" do
    @user.habits.destroy_all

    post today_eod_acknowledge_path
    assert_response :redirect

    get dashboard_path
    assert_response :success

    assert_select "#today-end-of-day", count: 0
    assert_select "#today-battlefield-end-day-host .lp-today-empty-cta__pill", count: 1
  end
end
