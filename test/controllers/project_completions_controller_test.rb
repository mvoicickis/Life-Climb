# frozen_string_literal: true

require "test_helper"

class ProjectCompletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "money",
      title: "Financial freedom",
      ideal_scene: "Calm savings",
      current_reality: "Building budget",
      next_win: "Launch Beta",
      today_mission: "Review my budget",
      closer_percent: 20
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    @plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan", title: "Plan", position: 0
    )
    @project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "Cut spend", position: 0
    )
  end

  test "not yet leaves mountain percent unchanged" do
    post project_completions_path, params: { project_id: @project.id, decision: "not_yet" }
    assert_redirected_to dashboard_path
    assert_equal 0, @goal.reload.progress_percent
    assert_not @project.reload.completed?
  end

  test "done moves mountain and completes ancestors" do
    post project_completions_path, params: { project_id: @project.id, decision: "done" }
    assert_redirected_to dashboard_path
    assert @project.reload.completed?
    assert @plan.reload.completed?
    assert @goal.reload.completed?
    assert_equal 100, @goal.progress_percent
  end
end
