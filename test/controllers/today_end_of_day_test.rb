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

  test "battles cleared with open basics shows inline ack and focused basics without end-of-day card" do
    @todo.update!(completed_at: Time.current)

    get dashboard_path
    assert_response :success

    assert_select ".lp-today-v2-inline-ack", text: /All battles won today/
    assert_select "#today-end-of-day", count: 0
    assert_select ".lp-dash-anytime.is-focus", count: 1
    assert_select "#today_habit_#{@habit.id}", count: 1
  end

  test "battles and basics cleared shows step 1 win takeover" do
    @todo.update!(completed_at: Time.current)
    @habit.completions.create!(user: @user, completed_on: Date.current, points_awarded: 5)

    get dashboard_path
    assert_response :success

    assert_select "#today-end-of-day.lp-today-v2-eod-takeover.is-flow", count: 1
    assert_select ".lp-today-v2-eod-win__title", text: "You cleared the field"
    assert_select ".lp-today-v2-eod-win__stats", text: /You won 1 of 1 battles/
    assert_select ".lp-today-v2-eod-plan", count: 0
    assert_select ".lp-dash-anytime.is-focus", count: 0
  end

  test "acknowledge advances to step 2 plan" do
    @todo.update!(completed_at: Time.current)
    @habit.completions.create!(user: @user, completed_on: Date.current, points_awarded: 5)

    post today_eod_acknowledge_path
    assert_redirected_to dashboard_path
    follow_redirect!

    assert_select ".lp-today-v2-eod-plan__title", text: "What are you certain you can do tomorrow?"
    assert_select ".lp-today-v2-eod-win", count: 0
  end

  test "plan tomorrow battle creates scheduled day goal and stays on step 2" do
    @todo.update!(completed_at: Time.current)
    @habit.completions.create!(user: @user, completed_on: Date.current, points_awarded: 5)
    project = @user.strategy_goals.for_kind("project").first

    post today_eod_acknowledge_path
    follow_redirect!

    post today_plan_tomorrow_battle_path,
         params: { project_id: project.id, title: "Outline deck", schedule: "tomorrow" }
    assert_redirected_to dashboard_path
    assert_match(/planning points/, flash[:notice].to_s)
    follow_redirect!

    battle = @user.strategy_goals.find_by!(horizon: "day", title: "Outline deck")
    assert_equal Date.current + 1.day, battle.scheduled_on
    assert_equal project.id, battle.parent_id
    assert_select ".lp-today-v2-eod-plan__chip", text: /Outline deck/
    assert_select ".lp-today-v2-eod-closed", count: 0
    assert_select ".lp-today-v2-eod-plan", count: 1
  end

  test "add for today exits flow and clears acknowledge" do
    @todo.update!(completed_at: Time.current)
    @habit.completions.create!(user: @user, completed_on: Date.current, points_awarded: 5)
    project = @user.strategy_goals.for_kind("project").first

    post today_eod_acknowledge_path
    follow_redirect!

    post today_plan_tomorrow_battle_path,
         params: { project_id: project.id, title: "One more thing", schedule: "today" }
    assert_redirected_to dashboard_path
    follow_redirect!

    assert_select "#today-end-of-day", count: 0
    assert_select ".lp-today-v2-row", text: /One more thing/
  end
end
