# frozen_string_literal: true

require "test_helper"

class BattleAnglesControllerTest < ActionDispatch::IntegrationTest
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
    @project_leaf = practice_leaf_for!(@project)
    @battle = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @project_leaf, horizon: "day",
      title: "Cancel subscription", scheduled_on: Date.current, position: 0
    )
  end

  test "not yet queues tomorrow battle without angle card UI on Today V2" do
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    dismiss_onboarding_missions!(@user)
    todo = @user.daily_todos.find_by!(strategy_goal_id: @battle.id)

    post complete_daily_todo_path(todo)
    follow_redirect!

    post project_completions_path, params: { project_id: @project_leaf.id, decision: "not_yet" }
    assert_redirected_to dashboard_path
    follow_redirect!

    assert_equal 0, @goal.reload.progress_percent
    assert_select ".lp-dash-battle-angles__chip", minimum: 1
    assert_select "#today-battlefield-win", count: 1
    assert_today_v2_shell!

    angle = Strategy::BattleAngles.for(project: @project_leaf).first
    post battle_angles_path, params: { project_id: @project_leaf.id, title: angle }
    assert_redirected_to dashboard_path
    follow_redirect!

    tomorrow = @user.strategy_goals.find_by!(horizon: "day", title: angle, parent_id: @project_leaf.id)
    assert_equal Date.current + 1.day, tomorrow.scheduled_on
    assert_match(/Tomorrow.?s battle is set/i, flash[:notice].to_s + response.body)
    assert_select ".lp-dash-battle-angles", count: 0
    assert_equal Date.current + 1.day, tomorrow.scheduled_on
  end

  test "rejects angle create on completed project" do
    @project.complete!
    Strategy::SyncCompletion.call(project: @project)

    post battle_angles_path, params: {
      project_id: @project.id,
      title: I18n.t("dash.battle_angles.templates.fifteen", project: "Cut spend")
    }
    assert_redirected_to dashboard_path
    assert_match(/can.?t take another battle/i, flash[:alert].to_s)
  end
end
