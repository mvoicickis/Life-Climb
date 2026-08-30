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

  test "battles and basics cleared shows end-of-day card" do
    @todo.update!(completed_at: Time.current)
    @habit.completions.create!(user: @user, completed_on: Date.current, points_awarded: 5)

    get dashboard_path
    assert_response :success

    assert_select "#today-end-of-day", count: 1
    assert_select ".lp-today-v2-inline-ack", text: /Basics logged for today/
    assert_select ".lp-dash-anytime.is-focus", count: 0
  end

  test "plan tomorrow battle creates scheduled day goal" do
    @todo.update!(completed_at: Time.current)
    @habit.completions.create!(user: @user, completed_on: Date.current, points_awarded: 5)
    project = @user.strategy_goals.for_kind("project").first

    post today_plan_tomorrow_battle_path, params: { project_id: project.id, title: "Outline deck" }
    assert_redirected_to dashboard_path

    battle = @user.strategy_goals.find_by!(horizon: "day", title: "Outline deck")
    assert_equal Date.current + 1.day, battle.scheduled_on
    assert_equal project.id, battle.parent_id
  end
end
