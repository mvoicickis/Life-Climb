# frozen_string_literal: true

require "application_system_test_case"

class QuantityProjectCardMobileTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(390, 844)

    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship the MVP",
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Design battle card",
      closer_percent: 40,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "MVP path", position: 0
    )
    @quant = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Read book", position: 0,
      target_amount: 700, unit: "pages", current_amount: 7
    )
    practice_leaf_for!(@quant).children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Read chapter",
      scheduled_on: Date.current, position: 0
    )
    @plain = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Launch site", position: 1
    )
  end

  test "mobile carousel shows quantity label and keeps plain card status" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey.reload, goal_id: @goal.id, plan_id: @plan.id, focus_id: @quant.id)
    assert_selector ".lp-climb-path", wait: 5
    assert_selector ".lp-climb-path__node.is-current .lp-climb-path__meta.is-quantity",
                    text: /7\s*\/\s*700\s*pages/i, wait: 5
    page.execute_script(<<~JS)
      const node = [...document.querySelectorAll(".lp-climb-path__node")]
        .find((el) => /Launch site/i.test(el.textContent || ""));
      node?.scrollIntoView({ block: "center" });
    JS
    assert_selector ".lp-climb-path__node", text: /Launch site/i, wait: 5

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/quantity-section-cards-mobile.png")

    # Card stays inside the climb path scroll region (no horizontal blowout).
    metrics = page.evaluate_script(<<~JS)
      (() => {
        const rail = document.querySelector(".lp-climb-path");
        const card = document.querySelector(".lp-climb-path__node.is-current");
        if (!rail || !card) return { ok: false };
        const rr = rail.getBoundingClientRect();
        const cr = card.getBoundingClientRect();
        return {
          ok: true,
          cardWidth: Math.round(cr.width),
          railWidth: Math.round(rr.width),
          withinRail: cr.left >= rr.left - 8 && cr.right <= rr.right + 8
        };
      })()
    JS
    assert metrics["ok"]
    assert metrics["withinRail"], "quantified card should stay within climb path"
    assert_operator metrics["cardWidth"], :>, 120
    assert_operator metrics["cardWidth"], :<=, metrics["railWidth"] + 8
  end
end
