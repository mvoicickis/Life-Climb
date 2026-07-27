# frozen_string_literal: true

require "test_helper"

class CampNotebookNuxTest < ActionDispatch::IntegrationTest
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
      closer_percent: 20,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
  end

  test "new climber lands on first-climb coach instead of crowded mountain" do
    get life_journey_path(@journey)
    assert_response :success
    assert_select "#first-climb-coach"
    assert_select ".lp-first-climb__cta[value=?]", "Start my climb"
    assert_select "#strategy-camp-notebook", count: 0
    assert_select ".lp-world-hud__chip.is-sp", count: 0
  end

  test "creating a plan focuses that plan notebook instead of the goal" do
    post strategy_goals_path, params: {
      life_area_id: @area.id,
      life_journey_id: @journey.id,
      parent_id: @goal.id,
      horizon: "plan",
      title: "Increase Income"
    }
    plan = @user.strategy_goals.for_kind("plan").last
    assert_redirected_to life_journey_path(@journey, focus_id: plan.id)

    follow_redirect!
    assert_select "#strategy-camp-notebook.is-open"
    assert_select ".lp-camp-notebook__panel.is-plan:not([hidden])"
    assert_select ".lp-camp-notebook__title", text: /Increase Income/
    assert_select ".lp-camp-notebook__add.is-project"
    assert_match(/Add project/i, response.body)
  end

  test "after first plan the dock offers enter plan" do
    @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Find Job", position: 0
    )

    get life_journey_path(@journey)
    assert_response :success
    assert_select ".lp-strategy-fight__cta.is-primary", text: /Enter Plan/i
    assert_select ".lp-camp-guide__body", text: /Tap a plan/i
  end

  test "handoff add plan deep-links into notebook" do
    handoff = Strategy::Handoff.for(user: @user, journey: @journey)
    assert_includes handoff[:href], "notebook=1"
  end
end
