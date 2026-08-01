# frozen_string_literal: true

require "test_helper"

class StrategyHierarchyReadyTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
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
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
  end

  test "false until plan project and battle exist" do
    refute Strategy::HierarchyReady.call(user: @user, journey: @journey)
    refute Strategy::HierarchyReady.call(user: @user, goal: @goal)

    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan", title: "Get interviews", position: 0
    )
    refute Strategy::HierarchyReady.call(user: @user, goal: @goal)

    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Improve apps", position: 0
    )
    refute Strategy::HierarchyReady.call(user: @user, goal: @goal)

    project_leaf = practice_leaf_for!(project)
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project_leaf, horizon: "day",
      title: "Make 5 emails better", scheduled_on: Date.current, position: 0
    )
    assert Strategy::HierarchyReady.call(user: @user, goal: @goal)
    assert Strategy::HierarchyReady.call(user: @user, journey: @journey)
  end
end
