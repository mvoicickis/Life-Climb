# frozen_string_literal: true

require "test_helper"

class PlanRailOverflowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    allow_extra_climbs!(@user)
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

    6.times do |i|
      @goal.children.create!(
        user: @user,
        life_area: @area,
        life_journey: @journey,
        horizon: "plan",
        title: "Overflow plan #{i + 1}",
        position: i
      )
    end
  end

  test "mountain plan rail renders arrow carousel and plan card menus" do
    get life_journey_path(@journey, goal_id: @goal.id)
    assert_response :success

    assert_select ".lp-rpg.is-v4-phone"
    assert_select ".lp-trail-hud__plans"
    assert_select ".lp-trail-hud__plan", minimum: 6
    assert_select ".lp-trail-hud__plan", text: /Overflow pl/i
    assert_select ".lp-trail-hud__plan.is-active", minimum: 1
    assert_select ".lp-rpg-paths", count: 0
    assert_select ".lp-rpg-plan-rail__arrow", count: 0
    assert_select ".lp-rpg-path-focus", count: 0
  end
end
