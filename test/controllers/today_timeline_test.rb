# frozen_string_literal: true

require "test_helper"

class TodayTimelineTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
    @area = @user.primary_focused_journey.life_area
    @journey = @user.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.find(&:plan?)
    @section = @plan.children.find(&:project?)
    @leaf = @section.children.find(&:project?)
    @todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Ship auth")

    @user.habits.destroy_all
    @user.habits.create!(
      name: "Meditate", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth"
    )
  end

  test "Today renders compressed timeline and Anytime without section headers" do
    get dashboard_path
    assert_response :success

    assert_select ".lp-dash-header", count: 1
    assert_select ".lp-dash-timeline", count: 1
    assert_select ".lp-dash-anytime", count: 1
    assert_select ".lp-dash-anytime .lp-dash-tcard.is-habit .lp-dash-tcard__title", text: "Meditate"
    assert_select ".lp-dash-section.is-battles", count: 0
    assert_select ".lp-dash-section.is-quests", count: 0
    assert_select ".lp-dash-section.is-habits", count: 0
    assert_no_match(/class="[^"]*is-battles/, response.body)
    assert_select ".lp-dash-tcard__win", minimum: 1
    assert_match(/min-height:\s*44px/, File.read(Rails.root.join("app/assets/tailwind/application.css")))
  end

  test "creating a timed battle places it in the timeline not Unscheduled" do
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
    assert_select ".lp-dash-timeline__item .lp-dash-tcard__title", text: "Deep work block"
    assert_select ".lp-dash-timeline__unscheduled .lp-dash-tcard__title", text: "Deep work block", count: 0
  end

  test "inline Set time moves an unscheduled todo into the timeline" do
    assert_not @todo.timed?

    travel_to Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 10, 0, 0) do
      get dashboard_path
      assert_response :success
      assert_select ".lp-dash-timeline__unscheduled .lp-dash-tcard[data-todo-id=?]", @todo.id.to_s
      assert_select ".lp-dash-tcard.is-needs-time[data-todo-id=?]", @todo.id.to_s
      assert_select ".lp-dash-tcard[data-todo-id=?] .lp-dash-tcard__timechip", @todo.id.to_s
      assert_select ".lp-dash-tcard[data-todo-id=?] .lp-dash-tcard__win--primary", @todo.id.to_s
      assert_select ".lp-dash-tcard[data-todo-id=?] .lp-dash-tcard__menu", @todo.id.to_s
      assert_match(/I did it/, response.body)

      patch daily_todo_path(@todo), params: {
        daily_todo: { start_time: "16:00", end_time: "16:45" }
      }
      assert_redirected_to dashboard_path
      assert @todo.reload.timed?

      get dashboard_path
      assert_response :success
      assert_select ".lp-dash-timeline__item .lp-dash-tcard.is-ready[data-todo-id=?]", @todo.id.to_s
      assert_select ".lp-dash-timeline__unscheduled .lp-dash-tcard[data-todo-id=?]", @todo.id.to_s, count: 0
      assert_match(/16:00/, response.body)
      assert_match(/counts today/, response.body)
    end
  end

  test "untimed battle shows actionable timechip before overdue hour" do
    assert_not @todo.timed?
    travel_to Time.zone.local(
      Date.current.year, Date.current.month, Date.current.day,
      Strategy::NextAction::OVERDUE_AFTER_HOUR - 1, 0, 0
    ) do
      get dashboard_path
      assert_response :success
      assert_select ".lp-dash-tcard.is-needs-time[data-todo-id=?]", @todo.id.to_s
      assert_select ".lp-dash-tcard[data-todo-id=?] button.lp-dash-tcard__timechip", @todo.id.to_s
      assert_match(/Add a time so it counts/, response.body)
      assert_select ".lp-dash-tcard[data-todo-id=?] .lp-dash-tcard__win--primary", @todo.id.to_s
    end
  end

  test "untimed battle hides actionable timechip at overdue hour" do
    assert_not @todo.timed?
    travel_to Time.zone.local(
      Date.current.year, Date.current.month, Date.current.day,
      Strategy::NextAction::OVERDUE_AFTER_HOUR, 0, 0
    ) do
      get dashboard_path
      assert_response :success
      assert_select ".lp-dash-tcard.is-needs-time[data-todo-id=?]", @todo.id.to_s, count: 0
      assert_select ".lp-dash-tcard[data-todo-id=?] button.lp-dash-tcard__timechip", @todo.id.to_s, count: 0
      assert_select ".lp-dash-tcard[data-todo-id=?] .lp-dash-tcard__timechip.is-muted", @todo.id.to_s
      assert_match(/No time set/, response.body)
      assert_select ".lp-dash-tcard[data-todo-id=?] .lp-dash-tcard__win--primary", @todo.id.to_s
    end
  end

  test "header shows shield badge when streak is at risk (banner no longer carries shield line)" do
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
      assert_select "[data-next-action-key='streak_at_risk']", count: 1
      assert_select ".lp-dash-next__shield", count: 0
      assert_select "[data-day-shield='ready']", minimum: 1
      assert_select "[data-commitment-progress]", minimum: 1
    end
  end

  test "miss settlement on Today load fades a missed card and spends AP without shield" do
    @todo.update!(start_time: "08:00", end_time: "09:00", lp_reward: 10, miss_settled_at: nil)
    @user.update!(day_shields_available: 0, day_shield_on: Date.current, total_points: 50)

    travel_to Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 12, 0, 0) do
      assert_difference -> { @user.reload.life_points }, -5 do
        get dashboard_path
      end
      assert_response :success
      assert_select ".lp-dash-tcard.is-missed[data-todo-id=?]", @todo.id.to_s
    end
  end
end
