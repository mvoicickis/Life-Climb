# frozen_string_literal: true

require "test_helper"

class FormControlNormalizeTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @user.update!(character: "fox", support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY, User::DAY_SHIELD_TIP_KEY ])
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
    @journey = @user.primary_focused_journey
    @area = @journey.life_area

    @user.habits.destroy_all
    @user.habits.create!(
      name: "Pages", unit: "pages", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", goal: 10,
      quantity_checkin: true
    )
  end

  test "Today quantity amount uses spinner-normalized class" do
    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-anytime input[type=number].lp-dash-tcard__amount", minimum: 1
  end

  test "gap panel ships custom qty checkbox class and time input shell class" do
    @journey.update!(
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
    assert_select "input.lp-commitment-gap__qty-check[type=checkbox]", count: 1
    assert_select "#commitment-gap-panel input[type=time].lp-input", minimum: 1
  end
end
