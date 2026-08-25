# frozen_string_literal: true

require "test_helper"

class ClimbRewardFlowTest < ActionDispatch::IntegrationTest
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
      today_mission: "Write tests",
      closer_percent: 20
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    goal = @user.strategy_goals.create!(life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0)
    plan = @user.strategy_goals.create!(life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan", position: 0)
    project = @user.strategy_goals.create!(life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Project", position: 0)
    project_leaf = practice_leaf_for!(project)
    battle = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project_leaf, horizon: "day",
      title: "Today Battle", scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    dismiss_onboarding_missions!(@user)
    @todo = @user.daily_todos.for_day.find_by!(strategy_goal_id: battle.id)
  end

  test "checkbox complete awards AP and celebrate without climb reward modal" do
    post complete_daily_todo_path(@todo)
    assert_redirected_to dashboard_path

    ap = flash[:ap_gained].to_i
    assert_operator ap, :>, 0
    assert flash[:battle_celebrate].present?
    assert_nil flash[:climb_reward], "ordinary checkbox taps must not open Climb Reward"
    assert_operator @user.reload.climb_streak_days, :>=, 1

    follow_redirect!
    assert_response :success
    assert_select "#climb-reward", count: 0
    assert_select ".lp-today-v2-header", count: 1
    assert_select ".lp-today-v2-field", count: 1
    assert_match(/data-battle-day-celebrate-value="true"/, response.body)
    assert_match(/data-battle-day-ap-gained-value="#{ap}"/, response.body)
  end

  test "when all items are done day is marked won on Today V2" do
    # Clear leftover onboarding mission so the day can fully clear via checkboxes.
    @user.missions.for_day.primary.incomplete.find_each do |mission|
      Missions::Complete.call(user: @user, mission: mission)
    end

    post complete_daily_todo_path(@todo)
    assert_redirected_to dashboard_path
    follow_redirect!

    assert_select ".lp-dash.is-battle-won", count: 1
    assert_select ".lp-dash-battle__won", count: 0
    assert_no_match(/Battle won\. Keep going/i, response.body)
    assert_select ".lp-dash-cta", count: 0
    assert_select "form[action=?]", battle_completion_path, count: 0
  end

  test "project done still opens climb reward modal" do
    post complete_daily_todo_path(@todo)
    follow_redirect!
    leaf = @todo.strategy_goal.parent
    post project_completions_path, params: { project_id: leaf.id, decision: "done" }
    assert_redirected_to dashboard_path
    assert flash[:climb_reward].present?
    follow_redirect!
    assert_select "#climb-reward"
  end
end
