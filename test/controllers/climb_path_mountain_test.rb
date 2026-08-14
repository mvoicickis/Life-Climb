# frozen_string_literal: true

require "test_helper"

class ClimbPathMountainTest < ActionDispatch::IntegrationTest
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
    @user.update!(
      support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ],
      character: "fox"
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Main trail", position: 0
    )
  end

  test "mountain lists every path project without a three-camp window" do
    8.times do |i|
      camp = @plan.children.create!(
        user: @user, life_area: @area, life_journey: @journey,
        horizon: "project", title: "Camp #{i}", position: i
      )
      camp.complete! if i < 2
    end

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select ".lp-climb-path.is-list"
    assert_select ".lp-climb-path__kicker", text: /What gets me there/
    8.times do |i|
      assert_select ".lp-climb-path__project .lp-climb-path__title", text: "Camp #{i}"
    end
    assert_select ".lp-climb-path__node.is-locked", count: 0
    assert_select ".lp-climb-path__face", count: 0
    assert_select "a.lp-climb-path__link", count: 0
    assert_select ".lp-climb-path__quests", count: 0
  end

  test "project cards are not tap-to-focus links" do
    @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Active camp", position: 0
    )
    @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Later camp", position: 1
    )

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select ".lp-climb-path__project .lp-climb-path__title", text: "Active camp"
    assert_select ".lp-climb-path__project .lp-climb-path__title", text: "Later camp"
    assert_select "a.lp-climb-path__link", count: 0
    assert_select ".lp-climb-path__menu-item", text: /Objectives/
  end
end
