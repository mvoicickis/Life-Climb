# frozen_string_literal: true

require "test_helper"

class FixedViewportMountainTest < ActionDispatch::IntegrationTest
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
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Main trail", position: 0
    )
  end

  test "mountain uses fixed-viewport shell with trail and battle stages" do
    project = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Resume", position: 0
    )
    project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Update CV", scheduled_on: Date.current, position: 0
    )

    get life_journey_path(@journey, focus_id: project.id)
    assert_response :success
    assert_select ".lp-rpg.is-focus-phase"
    assert_select ".lp-rpg__chrome-top"
    assert_select ".lp-rpg__stage"
    assert_select ".lp-rpg__stage-trail"
    assert_select ".lp-rpg__stage-battle"
    assert_select ".lp-rpg__chrome-bottom"
    assert_select ".lp-rpg-sheet.is-dominant"
    assert_select ".lp-rpg-context", count: 0
    assert_select ".lp-rpg-trail.is-windowed[data-controller~='trail-window'], .lp-rpg-world[data-controller~='trail-window']"
  end

  test "trail window controls appear only when more than three camps exist" do
    5.times do |i|
      camp = @plan.children.create!(
        user: @user, life_area: @area, life_journey: @journey,
        horizon: "project", title: "Camp #{i}", position: i
      )
      camp.complete! if i < 2
    end

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select "[data-trail-window-target='node']", count: 5
    assert_select "[data-trail-window-target='prev']"
    assert_select "[data-trail-window-target='next']"
    assert_match(/you are here/i, response.body)
  end

  test "trail window controls stay absent when three or fewer camps" do
    2.times do |i|
      @plan.children.create!(
        user: @user, life_area: @area, life_journey: @journey,
        horizon: "project", title: "Camp #{i}", position: i
      )
    end

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select "[data-trail-window-target='node']", count: 2
    assert_select "[data-trail-window-target='prev']", count: 0
    assert_select "[data-trail-window-target='next']", count: 0
  end

  test "focus polish de-dupes mountain percent and quiet labels" do
    project = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Daily battles", position: 0
    )
    project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Design battle card", scheduled_on: Date.current, position: 0
    )

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: project.id)
    assert_response :success
    assert_select ".lp-rpg-stats.is-compact"
    assert_select ".lp-rpg-stat.is-mountain", count: 0
    assert_select ".lp-rpg-stat.is-xp"
    assert_select ".lp-rpg-stat.is-streak"
    assert_select ".lp-rpg-stat.is-rank"
    assert_select ".lp-rpg-paths__label.is-quiet"
    assert_select ".lp-rpg-sheet-rail__label.is-quiet", minimum: 1
    assert_no_match(/you are here ·/i, response.body)
    assert_match(/You are here/i, response.body)
    assert_no_match(/PATHS · scroll/i, response.body)
    assert_no_match(/NOW · scroll/i, response.body)
  end
end
