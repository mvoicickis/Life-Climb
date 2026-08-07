# frozen_string_literal: true

require "application_system_test_case"

class ClimbPathPolishSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(390, 844)

    Onboarding::Run.call(
      user: @user, area_key: "career", title: "Ship LifePoints",
      ideal_scene: "App live", current_reality: "Building", next_win: "Launch",
      today_mission: "Write tests", closer_percent: 20, route_mission: true
    )
    @user.update!(
      support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ],
      character: "fox"
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Main trail", position: 0
    )
    @current = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Active camp", position: 0
    )
    @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Next camp", position: 1
    )
  end

  test "reduced motion makes nodes immediately visible without stuck opacity" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    page.driver.browser.execute_cdp(
      "Emulation.setEmulatedMedia",
      features: [ { name: "prefers-reduced-motion", value: "reduce" } ]
    )

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @current.id)
    assert_selector ".lp-climb-path", wait: 5
    assert_selector ".lp-climb-path__node.is-visible", minimum: 2, wait: 5

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const nodes = Array.from(document.querySelectorAll('.lp-climb-path__node'));
        if (!nodes.length) return { ok: false };
        const stuck = nodes.filter((el) => {
          const cs = getComputedStyle(el);
          return parseFloat(cs.opacity) < 0.95;
        });
        return {
          ok: true,
          count: nodes.length,
          visibleCount: nodes.filter((el) => el.classList.contains('is-visible')).length,
          stuck: stuck.length,
          transition: getComputedStyle(nodes[0]).transitionDuration
        };
      })()
    JS
    assert metrics["ok"]
    assert_equal metrics["count"], metrics["visibleCount"]
    assert_equal 0, metrics["stuck"]
  end

  test "tap haptic feature-detects vibrate present and absent without throwing" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @current.id)
    assert_selector ".lp-climb-path__node.is-current a.lp-climb-path__link[data-action*='climb-path#tap']", wait: 5

    result = page.evaluate_script(<<~JS)
      (() => {
        const link = document.querySelector(
          ".lp-climb-path__node.is-current a.lp-climb-path__link[data-action*='climb-path#tap']"
        );
        if (!link) return { ok: false, reason: "missing link" };

        link.addEventListener("click", (e) => e.preventDefault(), true);

        const calls = [];
        const original = navigator.vibrate;
        try {
          Object.defineProperty(navigator, "vibrate", {
            configurable: true,
            writable: true,
            value: (ms) => { calls.push(ms); return true; }
          });
          link.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }));
          const withVibrate = calls.slice();

          calls.length = 0;
          Object.defineProperty(navigator, "vibrate", {
            configurable: true,
            writable: true,
            value: undefined
          });
          let threw = false;
          try {
            link.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }));
          } catch (e) {
            threw = true;
          }

          return {
            ok: true,
            withVibrate,
            withoutCalls: calls.length,
            threw
          };
        } finally {
          if (original === undefined) {
            try { delete navigator.vibrate; } catch (_) {}
          } else {
            Object.defineProperty(navigator, "vibrate", {
              configurable: true,
              writable: true,
              value: original
            });
          }
        }
      })()
    JS

    assert result["ok"], result.inspect
    assert_includes result["withVibrate"], 12
    assert_equal 0, result["withoutCalls"]
    assert_equal false, result["threw"]
  end
end
