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

  test "restores stashed weekly day battle with weekdays" do
    project = @user.strategy_goals.create!(
      title: "Camp", horizon: "project", parent: @plan,
      life_area: @area, life_journey: @journey, position: 0
    )
    battle = @user.strategy_goals.create!(
      title: "Guitar", horizon: "day", parent: project,
      life_area: @area, life_journey: @journey, position: 0,
      scheduled_on: Date.current, repeat: "weekly", repeat_weekdays: [ 1, 3, 5 ]
    )
    delete strategy_goal_path(battle)
    assert_nil StrategyGoal.find_by(id: battle.id)

    post strategy_goal_restores_path
    assert_response :redirect
    restored = @user.strategy_goals.find_by!(title: "Guitar")
    assert restored.repeat_weekly?
    assert_equal [ 1, 3, 5 ], restored.repeat_weekdays_array
  end
end
