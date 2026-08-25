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

  test "gap panel markup is absent on Today V2 battlefield" do
    journey = @user.primary_focused_journey
    journey.update!(
      commitment_key: "medium",
      commitment_name: "Medium",
      commitment_habit_count: 3,
      commitment_battle_count: 3
    )
    3.times do |n|
      @user.habits.create!(
        name: "Gap habit #{n}", unit: "times", points: 5, frequency: "daily",
        active: true, show_on_home: true, quantity_checkin: false
      )
      @user.daily_todos.create!(
        title: "Timed #{n}", scheduled_on: Date.current, aspect_key: "career",
        start_time: "09:00", end_time: "10:00", position: 20 + n
      )
    end

    get dashboard_path
    assert_response :success
    assert_select "#commitment-gap-panel", count: 0
    assert_today_v2_shell!
  end
end
