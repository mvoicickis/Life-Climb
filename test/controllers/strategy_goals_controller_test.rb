# frozen_string_literal: true

require "test_helper"

class StrategyGoalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App in production",
      current_reality: "Still building",
      next_win: "Launch Beta",
      today_mission: "Write one test",
      closer_percent: 20
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
  end

  test "journey show is one-year planner without climb or universe chrome" do
    get life_journey_path(@journey)
    assert_response :success
    assert_match(/Your year plan/i, response.body)
    assert_match(/Plan here\. Score Strategy Points/i, response.body)
    assert_match(/Action Points/i, response.body)
    assert_match(/December 29/i, response.body)
    assert_match(/Strategy Points/i, response.body)
    assert_match(/Plan it together/i, response.body)
    assert_match(/Message me anytime/i, response.body)
    assert_select ".lp-strategy__horizon", minimum: 5
    assert_select ".lp-strategy__universe", count: 0
    assert_no_match(/Climb clarity/i, response.body)
    assert_select "#climb-purpose", count: 0
  end

  test "year goal locks due_on to December 29" do
    post strategy_goals_path, params: {
      life_area_id: @area.id,
      life_journey_id: @journey.id,
      horizon: "year",
      title: "Ship studio this year"
    }
    assert_redirected_to life_journey_path(@journey, horizon: "year")
    year = @user.strategy_goals.for_horizon("year").last
    assert Strategy::YearCycle.dec29?(year.due_on)
    assert_equal Strategy::YearCycle.target_dec29, year.due_on
    assert_equal 15, @user.reload.strategy_points
  end

  test "month slots follow remaining months until Dec 29" do
    post strategy_goals_path, params: {
      life_area_id: @area.id,
      life_journey_id: @journey.id,
      horizon: "year",
      title: "Ship studio this year"
    }
    year = @user.strategy_goals.for_horizon("year").last
    slots = Strategy::YearCycle.remaining_month_slots(target: year.due_on)
    assert slots.any?
    assert_equal Date.new(year.due_on.year, 12, 29), slots.last[:due_on]

    first = slots.first
    post strategy_goals_path, params: {
      life_area_id: @area.id,
      life_journey_id: @journey.id,
      parent_id: year.id,
      horizon: "month",
      due_on: first[:due_on],
      title: "July chunk"
    }
    month = @user.strategy_goals.for_horizon("month").last
    assert_equal first[:due_on], month.due_on
  end

  test "year month week day cascade awards SP and fills today feeder" do
    post strategy_goals_path, params: {
      life_area_id: @area.id,
      life_journey_id: @journey.id,
      horizon: "year",
      title: "Ship studio this year"
    }
    year = @user.strategy_goals.for_horizon("year").last
    assert_equal 15, @user.reload.strategy_points

    post strategy_goals_path, params: {
      life_area_id: @area.id,
      life_journey_id: @journey.id,
      parent_id: year.id,
      horizon: "month",
      title: "Launch offer this month"
    }
    month = @user.strategy_goals.for_horizon("month").last
    assert month.due_on.present?
    assert_equal 20, @user.reload.strategy_points

    post strategy_goals_path, params: {
      life_area_id: @area.id,
      life_journey_id: @journey.id,
      parent_id: month.id,
      horizon: "week",
      due_on: month.due_on,
      title: "Finish landing page"
    }
    week = @user.strategy_goals.for_horizon("week").last
    assert_equal 25, @user.reload.strategy_points

    today = Date.current
    3.times do |i|
      post strategy_goals_path, params: {
        life_area_id: @area.id,
        life_journey_id: @journey.id,
        parent_id: week.id,
        horizon: "day",
        scheduled_on: today.to_s,
        title: "Day action #{i + 1}"
      }
    end

    @user.reload
    assert @user.strategy_points >= 40
    assert_operator @user.daily_todos.for_day(today).count, :>=, 3
    assert @user.daily_todos.for_day(today).where.not(strategy_goal_id: nil).exists?
  end

  test "sync days to today from journey" do
    year = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "year", title: "Year", position: 0
    )
    month = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: year, horizon: "month",
      title: "Month", due_on: year.due_on, position: 0
    )
    week = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: month, horizon: "week",
      title: "Week", due_on: month.due_on, position: 0
    )
    day = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: week, horizon: "day",
      title: "Sync me", scheduled_on: Date.current, position: 0
    )
    @user.daily_todos.for_day(Date.current).where(strategy_goal_id: day.id).delete_all

    patch life_journey_path(@journey), params: { sync_today: "1" }
    assert_redirected_to dashboard_path
    assert @user.daily_todos.for_day(Date.current).exists?(strategy_goal_id: day.id, title: "Sync me")
  end

  test "strategy brief saves on journey" do
    patch life_journey_path(@journey), params: {
      horizon: "brief",
      strategy_brief: { why: "Freedom", rules: "Ship weekly" }
    }
    assert_redirected_to life_journey_path(@journey, horizon: "brief")
    @journey.reload
    assert_equal "Freedom", @journey.strategy_brief_value("why")
    assert_equal "Ship weekly", @journey.strategy_brief_value("rules")
  end

  test "dashboard shows action points and strategy points" do
    get dashboard_path
    assert_response :success
    assert_match(/\bAP\b/, response.body)
    assert_match(/\bSP\b/, response.body)
  end

  test "dashboard empty feeder links to strategy when no battle items" do
    @user.daily_todos.for_day(Date.current).delete_all
    @journey.missions.for_day(Date.current).delete_all

    get dashboard_path
    assert_response :success
    assert_match(/Plan this week in Strategy/i, response.body)
  end
end
