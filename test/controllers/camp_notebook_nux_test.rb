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
    assert_select ".lp-rpg-glass", count: 0
  end

  test "creating a plan focuses that plan on the RPG mountain" do
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
    assert_select ".lp-rpg"
    assert_select ".lp-rpg-plan.is-focus", text: /Increase Income/
    assert_select ".lp-rpg-plan.is-focus", text: /Increase Income/
    assert_match(/Add project/i, response.body)
  end

  test "after first plan the trail shows the checkpoint" do
    @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Find Job", position: 0
    )

    get life_journey_path(@journey)
    assert_response :success
    assert_select ".lp-rpg-plan", text: /Find Job/i
    assert_select ".lp-rpg-world"
  end

  test "handoff add plan deep-links still available" do
    handoff = Strategy::Handoff.for(user: @user, journey: @journey)
    assert handoff[:href].present?
  end
end
