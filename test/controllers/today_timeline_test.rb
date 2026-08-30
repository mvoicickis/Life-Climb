# frozen_string_literal: true

require "test_helper"

class TodayTimelineTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
    dismiss_onboarding_missions!(@user)
    @area = @user.primary_focused_journey.life_area
    @journey = @user.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.find(&:plan?)
    @section = @plan.children.find(&:project?)
    @leaf = @section
    @todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Ship auth")

    @user.habits.destroy_all
    @user.habits.create!(
      name: "Meditate", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth"
    )
  end

  test "Today V2 renders battlefield shell without timeline or section headers" do
    enable_habits!
    get dashboard_path
    assert_response :success

    assert_today_v2_shell!
    assert_no_legacy_today_shell!
    assert_select ".lp-dash-section.is-battles", count: 0
    assert_select ".lp-dash-section.is-quests", count: 0
    assert_select ".lp-dash-section.is-habits", count: 0
    assert_battle_row!(title: "Ship auth", camp: "Auth")
    assert_match(/min-height:\s*44px/, File.read(Rails.root.join("app/assets/tailwind/application.css")))
  end

  test "creating a timed battle places it in the battlefield list" do
    post strategy_goals_path, params: {
      life_area_id: @area.id,
      life_journey_id: @journey.id,
      parent_id: @leaf.id,
      horizon: "day",
      title: "Deep work block",
      scheduled_on: Date.current,
      start_time: "14:00",
      end_time: "15:00"
    }
    assert_response :redirect

    todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Deep work block")
    assert todo.timed?
    assert_equal "14:00", todo.start_time.strftime("%H:%M")
    assert_equal "15:00", todo.end_time.strftime("%H:%M")

    get dashboard_path
    assert_response :success
    assert_battle_row!(title: "Deep work block", todo: todo)
    assert_select ".lp-dash-timeline__unscheduled", count: 0
  end

  test "timed battles render as flat rows without inline set-time UI" do
    assert_not @todo.timed?

    travel_to Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 10, 0, 0) do
      get dashboard_path
      assert_response :success
      assert_battle_row!(title: @todo.title, todo: @todo)
      assert_select ".lp-dash-timeline__unscheduled", count: 0
      assert_select ".lp-dash-tcard__timechip", count: 0
      assert_select ".lp-dash-tcard__menu", count: 0

      patch daily_todo_path(@todo), params: {
        daily_todo: { start_time: "16:00", end_time: "16:45" }
      }
      assert_redirected_to dashboard_path
      assert @todo.reload.timed?

      get dashboard_path
      assert_response :success
      assert_battle_row!(title: @todo.title, todo: @todo)
      assert_select ".lp-dash-timeline", count: 0
    end
  end

  test "untimed battle shows flat row without actionable timechip before overdue hour" do
    assert_not @todo.timed?
    travel_to Time.zone.local(
      Date.current.year, Date.current.month, Date.current.day,
      Strategy::NextAction::OVERDUE_AFTER_HOUR - 1, 0, 0
    ) do
      get dashboard_path
      assert_response :success
      assert_battle_row!(title: @todo.title, todo: @todo)
      assert_select ".lp-dash-tcard__timechip", count: 0
      assert_select ".lp-today-v2-row__check", minimum: 1
    end
  end

  test "untimed battle shows flat row without timechip at overdue hour" do
    assert_not @todo.timed?
    travel_to Time.zone.local(
      Date.current.year, Date.current.month, Date.current.day,
      Strategy::NextAction::OVERDUE_AFTER_HOUR, 0, 0
    ) do
      get dashboard_path
      assert_response :success
      assert_battle_row!(title: @todo.title, todo: @todo)
      assert_select ".lp-dash-tcard__timechip", count: 0
      assert_select ".lp-today-v2-row__check", minimum: 1
    end
  end

  test "streak at risk next-action banner is absent on Today V2 battlefield" do
    @todo.update!(start_time: "11:00", end_time: "12:00")
    @user.update!(
      climb_streak_days: 5,
      climb_streak_on: Date.current - 1,
      climb_streak_freezes: 0,
      day_shields_available: 1,
      day_shield_on: Date.current
    )
    travel_to Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 10, 0, 0) do
      get dashboard_path
      assert_response :success
      assert_select "[data-next-action-key='streak_at_risk']", count: 0
      assert_select ".lp-today-v2-header", count: 1
      assert_select "[data-commitment-progress]", count: 0
    end
  end

  test "miss settlement on Today load still spends AP without shield" do
    @todo.update!(start_time: "08:00", end_time: "09:00", lp_reward: 10, miss_settled_at: nil)
    @user.update!(day_shields_available: 0, day_shield_on: Date.current, total_points: 50)

    travel_to Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 12, 0, 0) do
      assert_difference -> { @user.reload.life_points }, -5 do
        get dashboard_path
      end
      assert_response :success
      assert_battle_row!(title: @todo.title, todo: @todo)
      assert_select ".lp-dash-tcard.is-missed", count: 0
    end
  end
end
