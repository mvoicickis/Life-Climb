# frozen_string_literal: true

require "application_system_test_case"

class HabitIdentityMobileTest < ApplicationSystemTestCase
  setup { enable_habits! }
  include ClimbTestHelper

  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(390, 844)
    seed_climb!(@user, today_mission: "Ship auth")
    @user.habits.destroy_all
    @user.habits.create!(
      name: "Read", unit: "pages", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", goal: 10,
      identity_label: "I am a reader"
    )
    @user.habits.create!(
      name: "Meditate", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth"
    )
    @user.habits.create!(
      name: "Walk", unit: "steps", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", goal: 5000,
      identity_label: "I am someone who moves"
    )
  end

  test "identity labels read quietly on Today and Habits without clutter" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-anytime", wait: 5

    assert_selector ".lp-dash-anytime .lp-habit-identity", text: "I am a reader"
    assert_selector ".lp-dash-anytime .lp-habit-identity", text: "I am someone who moves"
    assert_selector ".lp-dash-anytime .lp-dash-tcard__title", text: "Meditate"
    assert_selector ".lp-dash-anytime .lp-habit-identity", count: 2

    page.execute_script("document.querySelector('.lp-dash-anytime')?.scrollIntoView({block: 'center'})")
    sleep 0.3
    page.save_screenshot("/opt/cursor/artifacts/screenshots/habit-identity-today-mobile.png")

    visit habits_path
    assert_selector ".lp-habits", wait: 5
    assert_selector ".lp-habit-identity", text: "I am a reader"
    assert_selector ".lp-habit-identity", text: "I am someone who moves"
    assert_selector ".lp-habits__name", text: "Meditate"
    page.save_screenshot("/opt/cursor/artifacts/screenshots/habit-identity-habits-mobile.png")
  end
end
