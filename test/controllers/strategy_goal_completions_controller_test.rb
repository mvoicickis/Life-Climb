# frozen_string_literal: true

require "test_helper"

class StrategyGoalCompletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(character: "fox")
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "Live",
      current_reality: "Building",
      today_mission: "Write tests",
      closer_percent: 20,
      route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_area(@area.id).for_kind("goal").roots.first
    assert_not_nil @goal

    @plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan", title: "Path", position: 0
    )
    @project_a = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "A", position: 0
    )
    @project_b = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "B", position: 1
    )
  end

  test "manual complete on project survives resync after adding a sibling" do
    post strategy_goal_manual_completion_path(@project_a)
    assert_redirected_to life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @project_a.id)
    assert @project_a.reload.manually_completed?
    assert @project_a.completed?

    sibling = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "C", position: 2
    )
    Strategy::SyncCompletion.resync!(node: sibling)

    assert @project_a.reload.manually_completed?
    assert @project_a.completed?
  end

  test "reopen clears both timestamps and resumes auto tracking" do
    post strategy_goal_manual_completion_path(@project_a)
    assert @project_a.reload.manually_completed?

    delete strategy_goal_manual_completion_path(@project_a)
    assert_redirected_to life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @project_a.id)
    assert_nil @project_a.reload.manually_completed_at
    assert_nil @project_a.completed_at

    sibling = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "C", position: 2
    )
    Strategy::SyncCompletion.resync!(node: sibling)
    assert_nil @project_a.reload.completed_at
    assert_not @project_a.manually_completed?
  end

  test "manual complete on plan survives sibling project create resync" do
    post strategy_goal_manual_completion_path(@plan)
    assert @plan.reload.manually_completed?
    assert_equal 0, Strategy::Progress.percent(@plan)

    sibling = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "C", position: 2
    )
    Strategy::SyncCompletion.resync!(node: sibling)

    assert @plan.reload.manually_completed?
    assert @plan.completed?
    assert_operator Strategy::Progress.percent(@plan.reload), :<, 100
  end

  test "manually closing all projects auto-completes the plan without sticky flag" do
    post strategy_goal_manual_completion_path(@project_a)
    post strategy_goal_manual_completion_path(@project_b)

    assert @plan.reload.completed?
    assert_nil @plan.manually_completed_at
    assert @project_a.reload.manually_completed?
    assert @project_b.reload.manually_completed?
  end

  test "mountain show renders manually closed badge and honest percent" do
    post strategy_goal_manual_completion_path(@plan)
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select ".lp-rpg.is-v4-phone"
    assert_select ".lp-trail__peak-title", text: /Ship LifePoints/i
    assert_select ".lp-trail-hud"
    assert_select ".lp-trail-segments__bar[style*='--seg-fill: 0']", minimum: 1
    assert_equal 0, Strategy::Progress.percent(@plan.reload)
    assert_select ".lp-rpg-path", count: 0
  end

  test "trail unlocks later sibling after earlier project is manually closed" do
    post strategy_goal_manual_completion_path(@project_a)
    trail = Strategy::Trail.for(plan: @plan.reload)
    states = trail.nodes.map { |n| [ n.id, n.state ] }.to_h

    assert_equal :done, states[@project_a.id]
    assert_equal :current, states[@project_b.id]
  end

  test "climb path keeps menu on a manually closed project for reopen" do
    post strategy_goal_manual_completion_path(@project_a)
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @project_a.id)
    assert_response :success
    assert_select "#climb-path-project-#{@project_a.id} .lp-climb-path__menu-btn"
    assert_select "#climb-path-project-#{@project_a.id} .lp-climb-path__menu-item", text: I18n.t("strategy.rpg.reopen")
  end
end
