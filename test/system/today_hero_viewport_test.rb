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
    assert_selector ".lp-dash-hero__segs i", count: 10
    assert_selector ".lp-dash-anytime .lp-dash-tcard.is-habit.is-slot", minimum: 1
    assert_selector ".lp-dash-anytime .lp-dash-habit__quick", minimum: 2

    hero_h = page.evaluate_script("document.querySelector('.lp-dash-hero').getBoundingClientRect().height")
    assert hero_h < 280, "hero height should stay compact (got #{hero_h})"

    card_h = page.evaluate_script(<<~JS)
      document.querySelector('.lp-dash-anytime .lp-dash-tcard.is-habit.is-slot').getBoundingClientRect().height
    JS
    # Baseline was ~190px; tap floor keeps buttons at var(--lp-tap) (~44px).
    # Report honestly — do not assert a mockup 105px target.
    assert card_h < 190, "habit slot should be denser than ~190px baseline (got #{card_h})"
    puts "MEASURED_HABIT_SLOT_HEIGHT_375=#{card_h.round}"

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/today-hero-375x600.png")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/today-rpg-habit-slot-375.png")
  end
end
