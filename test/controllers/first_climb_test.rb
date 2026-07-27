# frozen_string_literal: true

require "test_helper"

class FirstClimbTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Become a licensed plumber",
      ideal_scene: "Own my van and clients",
      current_reality: "Working a day job",
      next_win: "Pass first exam section",
      today_mission: "Study",
      closer_percent: 5,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
  end

  test "new climber sees first-climb coach instead of crowded mountain chrome" do
    get life_journey_path(@journey)
    assert_response :success
    assert_select "#first-climb-coach"
    assert_select ".lp-first-climb__cta[value=?]", "Start my climb"
    assert_select "#strategy-camp-notebook", count: 0
    assert_select ".lp-world-hud__chip.is-sp", count: 0
  end

  test "first climb scaffolds plan project battle and opens today fight" do
    assert_difference -> { @user.strategy_goals.for_kind("day").count }, +1 do
      post first_climbs_path, params: {
        life_journey_id: @journey.id,
        plan_title: "Get certified",
        today_action: "Study chapter 1 for 20 minutes"
      }
    end

    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success
    assert_select ".lp-dash-human-win__body", text: /Study chapter 1/i
    assert_select ".lp-dash-route.is-first-climb", count: 0
    assert @user.daily_todos.for_day(Date.current).exists?(title: "Study chapter 1 for 20 minutes")
    assert Strategy::HierarchyReady.call(user: @user, journey: @journey)
  end

  test "today dead-end shows first-climb coach when spine empty" do
    get dashboard_path
    assert_response :success
    assert_select "#first-climb-coach"
    assert_select ".lp-first-climb__title", text: /today count/i
  end
end
