# frozen_string_literal: true

require "test_helper"

class SummitGlassBannerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    allow_extra_climbs!(@user)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Summit glass",
      ideal_scene: "Peak",
      current_reality: "Climbing",
      next_win: "Camp two",
      today_mission: "Steps",
      closer_percent: 15
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Path", position: 0
    )
    @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "First camp", position: 0
    )
  end

  test "builtin photo renders glass summit banner on peak without pole markup" do
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select ".lp-trail.is-builtin-mountain-photos"
    assert_select ".lp-trail__summit"
    assert_select ".lp-trail__summit-banner[data-action*='trail-canvas#toggleGoalMenu']"
    assert_select ".lp-trail__summit-banner-text.lp-trail__goal-title", text: /Summit glass/i
    assert_select ".lp-trail__summit-pole", count: 0
    assert_select ".lp-trail__summit-banner-wrap", count: 0
    assert_select ".lp-trail-hud", count: 0
  end

  test "custom photo renders glass control in HUD without on-trail summit" do
    photo = fixture_file_upload("mountain_trail_default.jpg", "image/jpeg")
    patch life_journey_path(@journey), params: {
      mountain_photo_intent: "upload",
      life_journey: { mountain_photo: photo }
    }

    get life_journey_path(@journey.reload, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select ".lp-trail.is-custom-mountain-photo"
    assert_select ".lp-trail-hud .lp-trail__summit-glass-hud .lp-trail__summit-banner"
    assert_select ".lp-trail__summit", count: 0
    assert_select ".lp-trail__summit-pole", count: 0
  end
end
