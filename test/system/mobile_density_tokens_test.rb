# frozen_string_literal: true

require "application_system_test_case"

# Density token pass — mobile confirmation @ 390x844.
class MobileDensityTokensTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(390, 844)

    @journey = seed_climb!(@user, today_mission: "Ship density")
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.find(&:plan?)
    @section = @plan.children.find(&:project?)

    @user.habits.destroy_all
    @user.habits.create!(
      name: "Meditate", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", life_journey: @journey
    )
  end

  test "mobile shells are denser while Mountain and tap targets stay put" do
    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-battle", wait: 5

    battle_pad = computed(".lp-dash-battle", "padding-top")
    row_pad = computed(".lp-dash-battle__item", "padding-bottom")
    assert_in_delta 12.0, battle_pad, 1.5, "battle card should use --lp-pad-card (~0.75rem)"
    assert_in_delta 10.4, row_pad, 1.5, "fight rows should use --lp-pad-row-y (~0.65rem)"
    check_h = computed(".lp-dash-check", "min-height")
    assert_in_delta 44.0, check_h, 1.0, "check hit area must stay ~2.75rem"
    page.save_screenshot("/opt/cursor/artifacts/screenshots/density-today-mobile.png")

    visit habits_path
    assert_selector ".lp-habits__card", wait: 5
    title_size = computed(".lp-habits__title", "font-size")
    assert title_size <= 20.0, "Habits title should use display-sm, got #{title_size}px"
    card_pad = computed(".lp-habits__card", "padding-top")
    assert_in_delta 12.0, card_pad, 1.5
    page.save_screenshot("/opt/cursor/artifacts/screenshots/density-habits-mobile.png")

    visit life_points_path
    assert_selector ".lp-progress", wait: 5
    assert_no_selector ".lp-dash-hero__hint--secondary"
    assert_operator page.all(".lp-dash-hero__hint").size, :<=, 1
    progress_title = computed(".lp-progress__title", "font-size")
    assert progress_title <= 20.0, "Journey title should use display-sm, got #{progress_title}px"
    page.save_screenshot("/opt/cursor/artifacts/screenshots/density-journey-mobile.png")

    visit settings_path
    assert_selector ".lp-home__title", wait: 5
    assert_selector ".lp-glass--pad"
    home_gap = page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector('.lp-home');
        return parseFloat(getComputedStyle(el).rowGap || getComputedStyle(el).gap);
      })()
    JS
    assert_in_delta 16.0, home_gap, 1.5, "You section stack should use --lp-space-4"
    you_title = computed(".lp-home__title", "font-size")
    assert you_title <= 20.0
    page.save_screenshot("/opt/cursor/artifacts/screenshots/density-settings-mobile.png")

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @section.id)
    assert_selector ".lp-rpg", wait: 5
    rpg_gap = page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector('.lp-rpg.is-focus-phase') || document.querySelector('.lp-rpg');
        if (!el) return null;
        return getComputedStyle(el).getPropertyValue('--lp-rpg-gap').trim();
      })()
    JS
    refute_equal "0.75rem", rpg_gap.to_s, "Mountain must keep its own --lp-rpg-gap, not Today space-3"
    nav_h = computed(".lp-dash-nav__link", "min-height")
    assert_in_delta 44.0, nav_h, 1.0
    page.save_screenshot("/opt/cursor/artifacts/screenshots/density-mountain-unchanged-mobile.png")
  end

  private

  def computed(selector, prop)
    page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector(#{selector.to_json});
        if (!el) return null;
        return parseFloat(getComputedStyle(el).getPropertyValue(#{prop.to_json}));
      })()
    JS
  end
end
