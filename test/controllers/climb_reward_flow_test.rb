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
    battle = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project, horizon: "day",
      title: "Today Battle", scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    @todo = @user.daily_todos.for_day.find_by!(strategy_goal_id: battle.id)
  end

  test "completing the day awards AP streak and climb reward" do
    post battle_completion_path
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success
    assert_operator flash[:ap_gained].to_i, :>, 0
    assert flash[:climb_reward].present?
    assert_operator @user.reload.climb_streak_days, :>=, 1
    assert_select "#climb-reward"
    assert_match(/Battle won|Climb reward/i, response.body)
    assert_select ".lp-climb-streak"
    assert_select ".lp-dash-battle__ring"
  end
end
