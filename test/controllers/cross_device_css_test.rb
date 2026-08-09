# frozen_string_literal: true

require "test_helper"

class CrossDeviceCssTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @user.update!(character: "fox", support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
  end

  test "authenticated Today body uses lp-min-h-screen utility" do
    get dashboard_path
    assert_response :success
    assert_select "body.lp-min-h-screen"
    assert_select "body.min-h-screen", count: 0
  end

  test "gap panel exposes tap-friendly controls markup" do
    @user.habits.active.on_home.update_all(show_on_home: false)
    journey = @user.primary_focused_journey
    journey.update!(
      commitment_key: "medium",
      commitment_name: "Medium",
      commitment_habit_count: 3,
      commitment_battle_count: 3
    )

    get dashboard_path
    assert_response :success
    assert_select ".lp-commitment-gap__plus", minimum: 1
    assert_select ".lp-commitment-gap__qty-toggle", count: 1
    assert_select "input.lp-commitment-gap__qty-check[type=checkbox]", count: 1
    assert_select ".lp-commitment-gap__link", minimum: 1
  end
end
