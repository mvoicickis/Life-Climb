# frozen_string_literal: true

require "application_system_test_case"

# Today redesign — hero + habits fit a short phone viewport.
class TodayHeroViewportTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    seed_climb!(@user, today_mission: "Viewport battle")
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

  test "hero and habits visible at 375 and 320" do
    page.driver.browser.manage.window.resize_to(375, 600)
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"

    assert_selector ".lp-dash-hero", wait: 5
    assert_selector ".lp-dash-hero__big"
    assert_selector ".lp-dash-hero__segs i", count: 14
    assert_selector ".lp-dash-anytime .lp-dash-tcard.is-habit.is-slot", minimum: 3
    assert_selector ".lp-dash-anytime .lp-dash-habit__r2.is-single-quick", count: 0
    assert_selector ".lp-dash-anytime .lp-dash-habit__qb.is-big", minimum: 3

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const card = document.querySelector('.lp-dash-anytime .lp-dash-tcard.is-habit.is-slot');
        const qb = document.querySelector('.lp-dash-habit__r2 .lp-dash-habit__qb.is-big');
        const qs = qb ? getComputedStyle(qb) : null;
        return {
          heroH: document.querySelector('.lp-dash-hero').getBoundingClientRect().height,
          cardH: card.getBoundingClientRect().height,
          cardW: card.getBoundingClientRect().width,
          qbMinH: qs ? qs.minHeight : null,
          qbH: qb ? qb.getBoundingClientRect().height : null,
          qbW: qb ? qb.getBoundingClientRect().width : null,
          sigils: [...document.querySelectorAll('.lp-dash-tcard.is-habit .lp-dash-habit__r1 .lp-dash-habit__sig')].map((el) => el.textContent.trim())
        };
      })()
    JS

    assert metrics["heroH"] < 280, "hero height should stay compact (got #{metrics['heroH']})"
    assert metrics["cardH"] < 190, "habit slot denser than ~190px (got #{metrics['cardH']})"
    assert_equal "44px", metrics["qbMinH"], "quick button keeps var(--lp-tap) height"
    assert_operator metrics["qbH"], :>=, 43.5
    assert_operator metrics["qbW"], :>=, metrics["cardW"] * 0.6,
                    "single quick-add must stretch across the card (got #{metrics['qbW']} of #{metrics['cardW']})"
    assert_includes metrics["sigils"], "📖"
    assert_includes metrics["sigils"], "🗣"
    assert_includes metrics["sigils"], "💪"
    puts "MEASURED_HABIT_SLOT_HEIGHT_375=#{metrics['cardH'].round}"
    puts "MEASURED_SINGLE_QUICK_WIDTH_375=#{metrics['qbW'].round}"

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/today-rpg-layout-375.png")

    page.driver.browser.manage.window.resize_to(320, 600)
    visit dashboard_path
    assert_selector ".lp-dash-anytime .lp-dash-tcard.is-habit.is-slot", minimum: 3
    assert_selector ".lp-dash-habit__r2 .lp-dash-habit__qb.is-big", minimum: 1
    narrow = page.evaluate_script(<<~JS)
      (() => {
        const card = document.querySelector('.lp-dash-anytime .lp-dash-tcard.is-habit.is-slot');
        const qb = document.querySelector('.lp-dash-habit__r2 .lp-dash-habit__qb.is-big');
        return {
          cardW: card.getBoundingClientRect().width,
          qbW: qb.getBoundingClientRect().width,
          qbH: qb.getBoundingClientRect().height
        };
      })()
    JS
    assert_operator narrow["qbW"], :>=, narrow["cardW"] * 0.6
    assert_operator narrow["qbH"], :>=, 43.5
    page.save_screenshot("/opt/cursor/artifacts/screenshots/today-rpg-layout-320.png")
  end
end
