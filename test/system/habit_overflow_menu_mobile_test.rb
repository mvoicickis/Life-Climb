# frozen_string_literal: true

require "application_system_test_case"

# Habits moved off Today V2 — overflow slot UI is gone; list lives on /habits.
class HabitOverflowMenuMobileTest < ApplicationSystemTestCase
  setup { enable_habits! }
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @journey = seed_climb!(@user, today_mission: "Log habits")
    dismiss_onboarding_missions!(@user)
    @user.habits.destroy_all
    @habit = @user.habits.create!(
      name: "Push-Ups",
      unit: "reps",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "growth",
      goal: 25,
      quantity_checkin: true,
      life_journey: @journey
    )
  end

  test "Today V2 omits habit slots; habits page lists the habit at 375 and 320" do
    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_today_v2_shell!
    assert_no_selector "#today_habit_#{@habit.id}"
    assert_no_selector ".lp-dash-anytime"

    [ 375, 320 ].each do |width|
      page.driver.browser.manage.window.resize_to(width, 844)
      visit habits_path
      assert_selector ".lp-habits__name", text: "Push-Ups", wait: 5
      card = find(".lp-habits__card", text: "Push-Ups")
      assert card.find(".lp-habits__name", text: "Push-Ups").visible?

      visit dashboard_path
      assert_no_selector "#today_habit_#{@habit.id}"
      assert_no_selector ".lp-dash-habit__menu"

      page.save_screenshot("/opt/cursor/artifacts/screenshots/habit-off-today-#{width}.png")
    end
  end
end
