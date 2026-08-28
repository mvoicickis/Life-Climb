# frozen_string_literal: true

require "test_helper"

class BattleReopensControllerTest < ActionDispatch::IntegrationTest
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
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: @plan.id, horizon: "project", title: "Base camp",
      color_key: "teal", trail_x: 0.48, trail_y: 0.72
    }
    @project = @user.strategy_goals.for_kind("project").last
    @battle = @user.strategy_goals.create!(
      title: "Win then reopen", horizon: "day", parent: @project,
      life_area: @area, life_journey: @journey, scheduled_on: Date.current, position: 0
    )
    @battle.complete!
  end

  test "reopens a completed battle" do
    post battle_reopen_path(@battle)
    assert_response :redirect
    assert_nil @battle.reload.completed_at
  end

  test "reopening a battle as turbo stream refreshes camp sheet without redirecting" do
    post battle_reopen_path(@battle), as: :turbo_stream

    assert_response :ok
    assert_includes @response.media_type, "turbo-stream"
    assert_match "trail-battles-#{@project.id}", response.body
    assert_match "trail-battle-#{@battle.id}", response.body
    assert_no_match "is-done is-check", response.body
    assert_nil @battle.reload.completed_at
  end
end
