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

  test "restoring deleted project reparents battles from holding" do
    holding = Strategy::HoldingProject.ensure!(user: @user, journey: @journey)
    loose = holding.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Always loose", scheduled_on: Date.current, position: 0
    )
    project = @user.strategy_goals.create!(
      title: "Camp with fight", horizon: "project", parent: @plan,
      life_area: @area, life_journey: @journey, position: 1, stage: 1
    )
    battle = project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Move back", scheduled_on: Date.current, position: 0
    )

    delete strategy_goal_path(project)
    assert_equal holding.id, battle.reload.parent_id

    post strategy_goal_restores_path
    restored = @user.strategy_goals.find_by!(title: "Camp with fight")
    assert_not_equal project.id, restored.id
    assert_equal restored.id, battle.reload.parent_id
    assert_equal holding.id, loose.reload.parent_id
  end

  test "restored project keeps stage position and completed state" do
    project = @user.strategy_goals.create!(
      title: "Placed camp", horizon: "project", parent: @plan,
      life_area: @area, life_journey: @journey, position: 2, stage: 1,
      completed_at: 1.hour.ago
    )
    delete strategy_goal_path(project)

    post strategy_goal_restores_path
    restored = @user.strategy_goals.find_by!(title: "Placed camp")
    assert_equal 1, restored.stage
    assert_equal 2, restored.position
    assert restored.completed?
  end

  test "restore does not duplicate today todos for reparented battles" do
    project = @user.strategy_goals.create!(
      title: "Todo camp", horizon: "project", parent: @plan,
      life_area: @area, life_journey: @journey, position: 0, stage: 0
    )
    battle = project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Today fight", scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    count_before = @user.daily_todos.where(strategy_goal_id: battle.id, scheduled_on: Date.current).count

    delete strategy_goal_path(project)
    post strategy_goal_restores_path

    count_after = @user.daily_todos.where(strategy_goal_id: battle.id, scheduled_on: Date.current).count
    assert_equal count_before, count_after
    assert_equal 1, count_after
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
