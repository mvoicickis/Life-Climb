# frozen_string_literal: true

require "test_helper"

class BattleWinsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "Live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Code",
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
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "Project", position: 0
    )
    @project_leaf = practice_leaf_for!(@project)
    @battle = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @project_leaf, horizon: "day",
      title: "Win this fight", scheduled_on: Date.current, position: 0
    )
  end

  test "winning a battle from mountain returns to mountain with celebrate flash" do
    assert_difference -> { @user.reload.life_points }, GameRules::BATTLE_TODO_LP do
      post battle_win_path(@battle)
    end

    assert @battle.reload.completed?
    assert_response :redirect
    assert_match(%r{/life_journeys/#{@journey.id}}, @response.redirect_url)
    assert_includes @response.redirect_url, "focus_id=#{@project_leaf.id}"
    assert_equal GameRules::BATTLE_TODO_LP, flash[:ap_gained].to_i
    assert flash[:battle_celebrate]

    follow_redirect!
    assert_response :success
    assert_select ".lp-rpg"
  end
end
