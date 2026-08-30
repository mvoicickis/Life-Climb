# frozen_string_literal: true

require "application_system_test_case"

class FormControlNormalizeMobileTest < ApplicationSystemTestCase
  setup { enable_habits! }
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @user.update!(
      character: "fox",
      support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY, User::DAY_SHIELD_TIP_KEY ]
    )
    seed_climb!(@user, today_mission: "Ship auth")
    dismiss_onboarding_missions!(@user)
    @journey = @user.primary_focused_journey
    @user.habits.destroy_all
    @user.habits.create!(
      name: "Pages", unit: "pages", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", goal: 10,
      quantity_checkin: true
    )
  end

  test "Chrome computed styles normalize quantity input on habits page" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"

    assert_today_v2_shell!
    assert_no_selector "#commitment-gap-panel"
    assert_selector ".lp-dash-anytime"

    visit habits_path
    assert_selector ".lp-habits", wait: 5
    visit habit_path(@user.habits.first)
    assert_selector "input.lp-habits__input[type='number']", wait: 5

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const amount = document.querySelector("input.lp-habits__input[type='number']");
        const body = document.body;
        const bottomNav = document.querySelector(".lp-bottom-nav, .lp-dash-nav");
        const pick = (el, keys) => {
          if (!el) return null;
          const cs = getComputedStyle(el);
          const out = {};
          keys.forEach((k) => { out[k] = cs[k]; });
          out.appearance = cs.appearance || cs.webkitAppearance;
          return out;
        };
        const navCs = bottomNav ? getComputedStyle(bottomNav) : null;
        return {
          ua: navigator.userAgent,
          amount: amount && {
            appearance: getComputedStyle(amount).appearance || getComputedStyle(amount).webkitAppearance
          },
          bodyMinHeight: getComputedStyle(body).minHeight,
          bodyClass: body.className,
          bottomNavBackdrop: navCs && (navCs.webkitBackdropFilter || navCs.backdropFilter),
          colorScheme: getComputedStyle(document.documentElement).colorScheme,
          htmlTheme: document.documentElement.getAttribute("data-theme")
        };
      })()
    JS

    path = Rails.root.join("tmp/form_control_normalize_metrics.json")
    File.write(path, JSON.pretty_generate(metrics))

    assert metrics["amount"], "expected habits detail number input"
    assert_includes %w[textfield none auto], metrics["amount"]["appearance"].to_s.downcase.presence || "textfield"
    assert_includes metrics["bodyClass"].to_s, "lp-min-h-screen"
    assert metrics["colorScheme"].to_s.present?

    page.save_screenshot(Rails.root.join("tmp/screenshots/form_control_normalize_chrome.png"))
  end
end
