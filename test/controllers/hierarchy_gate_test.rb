# frozen_string_literal: true

require "test_helper"

class HierarchyGateTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Find a job",
      ideal_scene: "Hired",
      current_reality: "Searching",
      today_mission: "Plan the path",
      closer_percent: 10,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
  end

  test "today stays reachable while hierarchy is still growing" do
    refute Strategy::HierarchyReady.call(user: @user)

    get dashboard_path
    assert_response :success
    assert_match(/Start my climb|Plan Your Route|See your mountain|Battle/i, response.body)

    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan", title: "Get interviews", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Improve apps", position: 0
    )
    get dashboard_path
    assert_response :success

    project_leaf = practice_leaf_for!(project)
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project_leaf, horizon: "day",
      title: "Make 5 emails better", scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)

    assert Strategy::HierarchyReady.call(user: @user)
    get dashboard_path
    assert_response :success
    assert_select ".lp-today-v2-field"
  end

  test "fight today reaches dashboard after cascade when spine is ready" do
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan", title: "Get interviews", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Improve apps", position: 0
    )
    project_leaf = practice_leaf_for!(project)
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project_leaf, horizon: "day",
      title: "Make 5 emails better", scheduled_on: Date.current, position: 0
    )

    patch life_journey_path(@journey), params: { sync_today: 1 }
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success
    assert_select ".lp-today-v2-field"
  end
end
