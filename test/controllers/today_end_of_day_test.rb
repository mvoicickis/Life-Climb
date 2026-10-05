# frozen_string_literal: true

require "test_helper"

class TodayEndOfDayTest < ActionDispatch::IntegrationTest
  setup { enable_habits! }
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @user.habits.destroy_all
    sign_in_as @user
    @journey = seed_climb!(@user, today_mission: "Ship auth")
    dismiss_onboarding_missions!(@user)
    @area = @journey.life_area
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    @todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Ship auth")
    @habit = @user.habits.create!(
      name: "Meditate", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, quantity_checkin: false
    )
  end

  test "battles cleared with open basics shows end day without ack or takeover" do
    @todo.update!(completed_at: Time.current)

    get dashboard_path
    assert_response :success

    assert_select ".lp-today-v2-eod-ack", count: 0
    assert_select "#today-battlefield-end-day-host .lp-today-battlefield-end-day__btn", count: 1
    assert_select "#today-end-of-day", count: 0
    assert_select ".lp-dash-anytime.is-focus", count: 1
    assert_select "#today_habit_#{@habit.id}", count: 1
  end

  test "battles and basics cleared shows end day only until tapped" do
    @todo.update!(completed_at: Time.current)
    @habit.completions.create!(user: @user, completed_on: Date.current, points_awarded: 5)

    get dashboard_path
    assert_response :success

    assert_select "#today-end-of-day", count: 0
    assert_select "#today-battlefield-end-day-host .lp-today-battlefield-end-day__btn", count: 1
    assert_select ".lp-dash-anytime.is-focus", count: 0
  end

  test "end day opens day won card" do
    @todo.update!(completed_at: Time.current)
    @habit.completions.create!(user: @user, completed_on: Date.current, points_awarded: 5)

    post today_end_day_path
    assert_redirected_to dashboard_path
    follow_redirect!

    assert_select "#today-end-of-day.lp-today-v2-eod-takeover.is-flow", count: 1
    assert_select ".lp-today-v2-eod-step--day-won", count: 1
    assert_select ".lp-today-v2-eod-card__detail", text: "1 battle won"
    assert_select ".lp-today-v2-eod-card__command", text: "Write one thing you will do tomorrow."
    assert_select ".lp-today-v2-eod-card__primary", text: "Save for tomorrow"
    assert_select ".lp-today-v2-mountain-link.is-add-on-mountain",
                  text: I18n.t("dash.end_of_day.steps.day_won.plan_on_mountain")
  end

  test "eod acknowledge alias opens day won" do
    @todo.update!(completed_at: Time.current)
    @habit.completions.create!(user: @user, completed_on: Date.current, points_awarded: 5)

    post today_eod_acknowledge_path
    assert_redirected_to dashboard_path
    follow_redirect!

    assert_select ".lp-today-v2-eod-step--day-won", count: 1
  end

  test "plan step does not show camp check on Today" do
    @todo.update!(completed_at: Time.current)
    @habit.completions.create!(user: @user, completed_on: Date.current, points_awarded: 5)

    post today_end_day_path
    follow_redirect!

    assert_select ".lp-today-v2-eod-step--day-won", count: 1
    assert_select ".lp-today-v2-eod-plan__camp", count: 0
    assert_select ".lp-dash-project-check", count: 0
    assert_select ".lp-today-v2-end-of-day__camp-check", count: 0
  end

  test "plan save ends day into sign-off using path project camp" do
    @todo.update!(completed_at: Time.current)
    @habit.completions.create!(user: @user, completed_on: Date.current, points_awarded: 5)
    project = Strategy::PathProject.resolve(user: @user, journey: @journey)
    assert project

    post today_end_day_path
    follow_redirect!

    post today_plan_tomorrow_battle_path,
         params: { title: "Outline deck", schedule: "tomorrow" },
         as: :json
    assert_response :success
    assert_equal dashboard_path, response.parsed_body["redirect_to"]

    battle = @user.strategy_goals.find_by!(horizon: "day", title: "Outline deck")
    assert_equal Date.current + 1.day, battle.scheduled_on
    assert_equal project.id, battle.parent_id

    get dashboard_path
    assert_select ".lp-today-v2-eod-step--closed", count: 1
    assert_select ".lp-today-v2-eod-step--day-won", count: 0
  end

  test "plan save json failure keeps user on card copy" do
    @todo.update!(completed_at: Time.current)
    @habit.completions.create!(user: @user, completed_on: Date.current, points_awarded: 5)

    post today_end_day_path
    follow_redirect!

    post today_plan_tomorrow_battle_path,
         params: { title: "", schedule: "tomorrow" },
         as: :json
    assert_response :unprocessable_entity
    assert_equal I18n.t("dash.battlefield.win_not_saved"), response.parsed_body["error"]
  end

  test "plan on mountain ends day and deep links open camp sheet" do
    @todo.update!(completed_at: Time.current)
    @habit.completions.create!(user: @user, completed_on: Date.current, points_awarded: 5)
    project = Strategy::PathProject.resolve(user: @user, journey: @journey)

    post today_end_day_path
    follow_redirect!

    post today_end_day_path, params: { plan_on_mountain: 1 }
    assert_redirected_to life_journey_path(@journey, open_camp: project.id)
  end
end
