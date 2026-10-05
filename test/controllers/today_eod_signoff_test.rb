# frozen_string_literal: true

require "test_helper"

class TodayEodSignoffTest < ActionDispatch::IntegrationTest
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

  test "sign-off card markup share reopen and tomorrow row" do
    @todo.update!(completed_at: Time.current)
    @user.update!(climb_streak_days: 4, climb_streak_on: Date.current)
    project = Strategy::PathProject.resolve(user: @user, journey: @journey)

    post today_end_day_path
    follow_redirect!

    post today_plan_tomorrow_battle_path,
         params: { title: "Call my mum", schedule: "tomorrow" },
         as: :json
    assert_response :success

    get dashboard_path
    assert_response :success

    assert_select ".lp-today-v2-eod-step--closed", count: 1
    assert_select ".lp-today-v2-eod-signoff__kicker", text: /See you tomorrow/
    assert_select ".lp-today-v2-eod-signoff__moon-icon svg", count: 1
    assert_select ".lp-today-v2-eod-signoff__goal", minimum: 1
    assert_select ".lp-today-v2-eod-signoff__camp-meta", text: /Camp \d+ of \d+/
    assert_select ".lp-today-v2-eod-signoff__tomorrow-title", text: "Call my mum"
    assert_select ".lp-today-v2-eod-signoff__streak", text: /4 days in a row/
    assert_select ".lp-today-v2-eod-signoff__streak-icon svg", count: 1
    assert_select "button.lp-today-v2-eod-signoff__share[data-action*='today-notch#shareRecap']",
                  text: I18n.t("dash.end_of_day.steps.closed.share_my_day")
    assert_select "#today-dash-root[data-controller*='today-notch']", count: 1
    assert_select "a.lp-today-v2-eod-signoff__reopen", text: I18n.t("dash.end_of_day.reopen_day")
    assert_equal project.id,
                 @user.strategy_goals.find_by!(title: "Call my mum", horizon: "day").parent_id
  end

  test "sign-off omits tomorrow row when nothing planned" do
    @todo.update!(completed_at: Time.current)

    post today_end_day_path
    follow_redirect!
    post today_end_day_path, params: { plan_on_mountain: 1 }
    follow_redirect!

    get dashboard_path
    assert_select ".lp-today-v2-eod-signoff__tomorrow", count: 0
  end
end
