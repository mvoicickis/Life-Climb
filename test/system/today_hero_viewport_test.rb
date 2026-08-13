# frozen_string_literal: true

require "application_system_test_case"

# Today redesign — hero + habits fit a short phone viewport.
class TodayHeroViewportTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    seed_climb!(@user, today_mission: "Viewport battle")
    @user.habits.destroy_all
    2.times do |i|
      @user.habits.create!(
        name: "Habit #{i + 1}", unit: "reps", points: 5, frequency: "daily",
        active: true, show_on_home: true, stat_type: "growth", goal: 20, quantity_checkin: true
      )
    end
  end

  test "hero and habits visible at 375x600" do
    page.driver.browser.manage.window.resize_to(375, 600)
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"

    assert_selector ".lp-dash-hero", wait: 5
    assert_selector ".lp-dash-hero__big"
    assert_selector ".lp-dash-anytime .lp-dash-tcard.is-habit", minimum: 1

    hero_h = page.evaluate_script("document.querySelector('.lp-dash-hero').getBoundingClientRect().height")
    assert hero_h < 280, "hero height should stay compact (got #{hero_h})"

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/today-hero-375x600.png")
  end
end
