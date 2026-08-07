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

  test "complete_battle banner appears on Mountain non-first-climb view" do
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

    assert_select ".lp-first-climb", count: 0
    assert_select ".lp-dash-next[data-next-action-key=complete_battle]", count: 1
    title = css_select(".lp-dash-next__title").text
    assert_match(/⚔️/, title)
    assert_match(/Send five emails/, title)
    assert_select ".lp-dash-next__face[src*='fox']", count: 1
    assert_select "a.lp-cta", text: I18n.t("strategy.next_action.complete_battle.cta")
  end

  test "first-climb view shows coach without NextAction banner" do
    get life_journey_path(@journey)
    assert_response :success

    assert_select "#first-climb-coach", count: 1
    assert_select ".lp-first-climb", count: 1
    assert_select ".lp-dash-next", count: 0
  end
end
