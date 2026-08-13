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
    assert_selector ".lp-dash-anytime .lp-dash-habit__r2.is-single-quick", minimum: 1
    assert_selector ".lp-dash-anytime .lp-dash-habit__r2:not(.is-single-quick)", minimum: 1

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const card = document.querySelector('.lp-dash-anytime .lp-dash-tcard.is-habit.is-slot');
        const single = document.querySelector('.lp-dash-habit__r2.is-single-quick .lp-dash-habit__qb');
        const dualForm = document.querySelector('.lp-dash-habit__r2:not(.is-single-quick) > form');
        const qs = single ? getComputedStyle(single) : null;
        return {
          heroH: document.querySelector('.lp-dash-hero').getBoundingClientRect().height,
          cardH: card.getBoundingClientRect().height,
          cardW: card.getBoundingClientRect().width,
          qbMinH: qs ? qs.minHeight : null,
          qbH: single ? single.getBoundingClientRect().height : null,
          singleW: single ? single.getBoundingClientRect().width : null,
          dualFormW: dualForm ? dualForm.getBoundingClientRect().width : null,
          sigils: [...document.querySelectorAll('.lp-dash-habit__sig')].map((el) => el.textContent.trim())
        };
      })()
    JS

    assert metrics["heroH"] < 280, "hero height should stay compact (got #{metrics['heroH']})"
    assert metrics["cardH"] < 190, "habit slot denser than ~190px (got #{metrics['cardH']})"
    assert_equal "44px", metrics["qbMinH"], "quick button keeps var(--lp-tap) height"
    assert_operator metrics["qbH"], :>=, 43.5
    assert_operator metrics["singleW"], :<, metrics["cardW"] * 0.55,
                    "single quick-add must not stretch full card width"
    assert_operator metrics["dualFormW"], :>, metrics["cardW"] * 0.3,
                    "dual quick-adds still share the row"
    assert_includes metrics["sigils"], "📖"
    assert_includes metrics["sigils"], "🗣"
    assert_includes metrics["sigils"], "💪"
    puts "MEASURED_HABIT_SLOT_HEIGHT_375=#{metrics['cardH'].round}"
    puts "MEASURED_SINGLE_QUICK_WIDTH_375=#{metrics['singleW'].round}"

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/today-rpg-layout-375.png")

    page.driver.browser.manage.window.resize_to(320, 600)
    visit dashboard_path
    assert_selector ".lp-dash-anytime .lp-dash-tcard.is-habit.is-slot", minimum: 3
    assert_selector ".lp-dash-habit__r2.is-single-quick .lp-dash-habit__qb", minimum: 1
    narrow = page.evaluate_script(<<~JS)
      (() => {
        const card = document.querySelector('.lp-dash-anytime .lp-dash-tcard.is-habit.is-slot');
        const single = document.querySelector('.lp-dash-habit__r2.is-single-quick .lp-dash-habit__qb');
        return {
          cardW: card.getBoundingClientRect().width,
          singleW: single.getBoundingClientRect().width,
          qbH: single.getBoundingClientRect().height
        };
      })()
    JS
    assert_operator narrow["singleW"], :<, narrow["cardW"] * 0.6
    assert_operator narrow["qbH"], :>=, 43.5
    page.save_screenshot("/opt/cursor/artifacts/screenshots/today-rpg-layout-320.png")
  end
end
