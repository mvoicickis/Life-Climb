# frozen_string_literal: true

require "test_helper"

# Legacy studio (v1) assertions retired — product is planning_v2 Mountain/Today.
class StudioFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Finish authentication",
      closer_percent: 20,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    plan = @goal.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "plan", title: "Build", position: 0
    )
    project = plan.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "project", title: "Auth", position: 0
    )
    project_leaf = practice_leaf_for!(project)
    project_leaf.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "day", title: "Finish authentication", scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @journey.life_area)
  end

  test "today shows v2 battle home" do
    get dashboard_path
    assert_response :success
    assert_match(/Today|Battle|Action Points/i, response.body)
    assert_select ".lp-dash-nav"
  end

  test "completing a synced battle todo earns action points" do
    todo = @user.daily_todos.for_day.find_by!(title: "Finish authentication")
    assert_difference -> { @user.reload.total_points }, todo.lp_reward.to_i do
      post complete_daily_todo_path(todo)
    end
    assert_redirected_to dashboard_path
  end

  test "journey page shows mountain progress story" do
    get life_points_path
    assert_response :success
    assert_match(/Journey|Mountain|Action Points/i, response.body)
  end

  test "nav includes mountain today journey you" do
    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-nav__link", text: /Mountain/i
    assert_select ".lp-dash-nav__link", text: /Today/i
    assert_select ".lp-dash-nav__link", text: /Journey/i
    assert_select ".lp-dash-nav__link", text: /You/i
    assert_select "a[href=?]", life_points_path
  end

  test "mountain page loads for focused journey" do
    get life_journey_path(@journey)
    assert_response :success
    assert_match(/LifePoints|Mountain/i, response.body)
    assert_select ".lp-rpg, #first-climb-coach"
  end
end
