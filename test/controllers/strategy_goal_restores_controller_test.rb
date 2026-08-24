# frozen_string_literal: true

require "test_helper"

class StrategyGoalRestoresControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    allow_extra_climbs!(@user)
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
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      horizon: "goal", title: "Trail summit"
    }
    @goal = @user.strategy_goals.for_kind("goal").last
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: @goal.id, horizon: "plan", title: "Main path"
    }
    @plan = @user.strategy_goals.for_kind("plan").last
  end

  test "restores stashed project within ttl" do
    project = @user.strategy_goals.create!(
      title: "Undo me", horizon: "project", parent: @plan,
      life_area: @area, life_journey: @journey, position: 99, color_key: "teal",
      trail_x: 0.5, trail_y: 0.6
    )
    delete strategy_goal_path(project)
    assert_nil StrategyGoal.find_by(id: project.id)

    assert_difference -> { @user.strategy_goals.where(title: "Undo me").count }, 1 do
      post strategy_goal_restores_path
    end
    assert_response :redirect
  end

  test "missing stash redirects with alert" do
    post strategy_goal_restores_path
    assert_response :redirect
  end
end
