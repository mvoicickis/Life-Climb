# frozen_string_literal: true

require "test_helper"

class MountainNextActionBannerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(character: "fox")
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Find a job",
      ideal_scene: "Hired",
      current_reality: "Searching",
      today_mission: "Plan the path",
      closer_percent: 10,
      route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
  end

  test "Mountain non-first-climb view never renders NextAction banner" do
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan",
      title: "Get interviews", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project",
      title: "Improve apps", position: 0
    )
    leaf = practice_leaf_for!(project)
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: leaf, horizon: "day",
      title: "Send five emails", scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)

    get life_journey_path(@journey)
    assert_response :success

    assert_select "#first-climb-coach", count: 0
    assert_select ".lp-rpg.is-v4-phone"
    assert_select "#mountain-trail.lp-trail.is-v4"
    assert_select "dialog#destination-coach", count: 0
    assert_select ".lp-rpg__chrome-top", count: 0
    assert_select ".lp-dash-next", count: 0
  end

  test "first-climb view shows destination overlay without NextAction banner" do
    get life_journey_path(@journey)
    assert_response :success

    assert_select ".lp-trail-destination", count: 1
    assert_select "#first-climb-coach", count: 0
    assert_select ".lp-dash-next", count: 0
  end
end
