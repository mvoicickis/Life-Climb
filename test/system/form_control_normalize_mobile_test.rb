# frozen_string_literal: true

require "application_system_test_case"

class FormControlNormalizeMobileTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @user.update!(
      character: "fox",
      support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY, User::DAY_SHIELD_TIP_KEY ]
    )
    seed_climb!(@user, today_mission: "Ship auth")
    @journey = @user.primary_focused_journey
    @user.habits.destroy_all
    @user.habits.create!(
      name: "Pages", unit: "pages", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", goal: 10,
      quantity_checkin: true
    )
    @journey.update!(
      commitment_key: "medium",
      commitment_name: "Medium",
      commitment_habit_count: 3,
      commitment_battle_count: 3
    )
  end

  test "Chrome computed styles normalize time checkbox and number chrome" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"

    visit dashboard_path
    assert_selector "#commitment-gap-panel", wait: 5

    find("[data-commitment-gap-target='battlePlus']").click
    assert_selector "#commitment-gap-panel input[type='time'].lp-input", wait: 3

    find("[data-commitment-gap-target='habitPlus']").click
    assert_selector "input.lp-commitment-gap__qty-check", wait: 3
    find("input.lp-commitment-gap__qty-check").set(true)

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const time = document.querySelector("#commitment-gap-panel input[type='time'].lp-input");
        const check = document.querySelector("input.lp-commitment-gap__qty-check");
        const amount = document.querySelector("input[type='number'].lp-dash-tcard__amount");
        const pick = (el, keys) => {
          if (!el) return null;
          const cs = getComputedStyle(el);
          const out = {};
          keys.forEach((k) => { out[k] = cs[k]; });
          out.appearance = cs.appearance || cs.webkitAppearance;
          return out;
        };
        return {
          ua: navigator.userAgent,
          time: pick(time, ["paddingRight", "borderRadius", "borderColor", "backgroundColor", "color"]),
          check: Object.assign(
            pick(check, ["width", "height", "borderRadius", "borderColor", "backgroundColor"]) || {},
            { checked: !!(check && check.checked) }
          ),
          amount: amount && {
            appearance: getComputedStyle(amount).appearance || getComputedStyle(amount).webkitAppearance
          },
          colorScheme: getComputedStyle(document.documentElement).colorScheme,
          htmlTheme: document.documentElement.getAttribute("data-theme")
        };
      })()
    JS

    path = Rails.root.join("tmp/form_control_normalize_metrics.json")
    File.write(path, JSON.pretty_generate(metrics))

    assert metrics["time"], "expected gap time input"
    assert metrics["check"], "expected gap qty checkbox"
    assert_equal "none", metrics["time"]["appearance"].to_s.downcase
    assert_equal "none", metrics["check"]["appearance"].to_s.downcase
    assert metrics["check"]["checked"]
    check_w = metrics["check"]["width"].to_s.to_f
    assert_in_delta 19.2, check_w, 2.0, "expected ~1.2rem checkbox width"
    assert metrics["colorScheme"].to_s.present?
    assert metrics["amount"], "expected Anytime quantity amount field"
    assert_includes %w[textfield none], metrics["amount"]["appearance"].to_s.downcase.presence || "textfield"

    page.save_screenshot(Rails.root.join("tmp/screenshots/form_control_normalize_chrome.png"))
  end
end
