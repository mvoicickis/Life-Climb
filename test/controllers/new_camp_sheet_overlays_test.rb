# frozen_string_literal: true

require "test_helper"

class NewCampSheetOverlaysTest < ActionDispatch::IntegrationTest
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
    @plan = @user.strategy_goals.for_kind("plan").not_holding.first
  end

  test "creating a camp on mountain appends finish slot and won strip targets" do
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select "#trail-sheet-stage"
    assert_select "#trail-sheet-panel-overlays"

    post strategy_goals_path, params: {
      life_area_id: @area.id,
      life_journey_id: @journey.id,
      parent_id: @plan.id,
      horizon: "project",
      title: "Test overlay camp"
    }, as: :turbo_stream

    assert_response :success
    camp = @plan.children.for_kind("project").find_by!(title: "Test overlay camp")
    assert_match %(action="append" target="trail-sheet-stage"), response.body
    assert_match %(action="append" target="trail-sheet-panel-overlays"), response.body
    assert_match "id=\"trail-camp-finish-#{camp.id}\"", response.body
    assert_match "id=\"trail-battles-done-slot-#{camp.id}\"", response.body
  end

  test "win on new camp battle shows finish card after overlay mount" do
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success

    post strategy_goals_path, params: {
      life_area_id: @area.id,
      life_journey_id: @journey.id,
      parent_id: @plan.id,
      horizon: "project",
      title: "Fresh camp"
    }, as: :turbo_stream
    camp = @plan.children.for_kind("project").find_by!(title: "Fresh camp")

    post strategy_goals_path, params: {
      life_area_id: @area.id,
      life_journey_id: @journey.id,
      parent_id: camp.id,
      horizon: "day",
      title: "Solo battle",
      scheduled_on: Date.current,
      repeat: "none"
    }, as: :turbo_stream
    battle = camp.children.for_kind("day").find_by!(title: "Solo battle")

    post battle_win_path(battle), params: { source: "camp_sheet" }, as: :turbo_stream
    assert_response :success
    assert_match %(action="replace" target="trail-camp-finish-#{camp.id}"), response.body
    assert_match I18n.t("strategy.rpg.trail.finish_camp_card.title"), response.body
    assert_match %(action="replace" target="trail-battles-done-slot-#{camp.id}"), response.body
    assert_match "has-won-today", response.body
  end
end
