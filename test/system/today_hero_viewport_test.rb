# frozen_string_literal: true

require "application_system_test_case"

# Today V2 — compact HP header fits short phone viewports; habits show on Today when enabled.
class TodayHeroViewportTest < ApplicationSystemTestCase
  setup { enable_habits! }
  include ClimbTestHelper

  setup do
    @user = users(:one)
    seed_climb!(@user, today_mission: "Viewport battle")
    dismiss_onboarding_missions!(@user)
    @user.habits.destroy_all
    @user.habits.create!(
      name: "Study", unit: "pages", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", goal: 2, quantity_checkin: true
    )
    @user.habits.create!(
      name: "German Study", unit: "duo units", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", goal: 5, quantity_checkin: true
    )
    @user.habits.create!(
      name: "Push-Ups", unit: "reps", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "standard",
      min_value: 10, max_value: 20, quantity_checkin: true
    )
  end

  test "V2 header fits at 375 and 320; habits show on Today when enabled" do
    page.driver.browser.manage.window.resize_to(375, 600)
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"

    assert_today_v2_shell!
    assert_no_legacy_today_shell!
    assert_selector ".lp-today-v2-header__avatar-img"
    assert_selector ".lp-today-v2-header__hp-num"
    assert_selector ".lp-today-v2-hp-bar"
    assert_selector ".lp-dash-anytime"

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const header = document.querySelector('.lp-today-v2-header');
        const nav = document.querySelector('.lp-dash-nav.is-today-v2');
        const tap = parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--lp-tap')) || 44;
        const navLink = document.querySelector('.lp-dash-nav.is-today-v2 .lp-dash-nav__link');
        return {
          headerH: header.getBoundingClientRect().height,
          navH: navLink?.getBoundingClientRect().height,
          tap: tap,
          vw: window.innerWidth
        };
      })()
    JS

    assert metrics["headerH"] < 200, "V2 header should stay compact (got #{metrics['headerH']})"
    assert_operator metrics["navH"].to_f, :>=, metrics["tap"] - 1.0,
                    "nav links keep tap target (got #{metrics['navH']})"

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/today-v2-header-375.png")

    visit habits_path
    assert_selector ".lp-habits__name", text: "Study", wait: 5
    assert_selector ".lp-habits__name", text: "German Study"
    assert_selector ".lp-habits__name", text: "Push-Ups"

    page.driver.browser.manage.window.resize_to(320, 600)
    visit dashboard_path
    assert_today_v2_shell!
    assert_selector ".lp-dash-anytime"

    narrow = page.evaluate_script(<<~JS)
      (() => {
        const header = document.querySelector('.lp-today-v2-header');
        return {
          headerH: header.getBoundingClientRect().height,
          vw: window.innerWidth
        };
      })()
    JS
    assert narrow["headerH"] < 200, "V2 header should stay compact at 320 (got #{narrow['headerH']})"
    page.save_screenshot("/opt/cursor/artifacts/screenshots/today-v2-header-320.png")
  end
end
