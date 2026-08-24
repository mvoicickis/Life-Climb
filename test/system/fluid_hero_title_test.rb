# frozen_string_literal: true

require "application_system_test_case"

# V4 destination title lives on the peak pennant (.lp-trail__peak-title).
# Compact flag width (~100–150px) is expected; Today still uses the dash hero.
class FluidHeroTitleTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Become a Rails developer",
      ideal_scene: "Shipping features",
      current_reality: "Learning",
      next_win: "First PR",
      today_mission: "Write one test",
      closer_percent: 20,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ], character: "fox")
    @journey = @user.reload.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "plan", title: "Skills path", position: 0
    )
    camp = @plan.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "project", title: "Rails camp", position: 0
    )
    practice_leaf_for!(camp).children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "day", title: "Write one test", scheduled_on: Date.current, position: 0
    )
  end

  test "destination title is fluid and untruncated on tall phone" do
    assert_destination_fluid_title(390, 844)
  end

  test "destination title is fluid and untruncated on short phone" do
    assert_destination_fluid_title(390, 568)
  end

  test "today climb band renders on tall phone" do
    assert_today_climb_band(390, 844)
  end

  test "today climb band renders on short phone" do
    assert_today_climb_band(390, 568)
  end

  private

  def sign_in_user!
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
  end

  def title_metrics(selector)
    page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector(#{selector.to_json});
        if (!el) return { ok: false, reason: "missing" };
        const cs = getComputedStyle(el);
        const r = el.getBoundingClientRect();
        const text = (el.textContent || "").trim();
        return {
          ok: true,
          text,
          fontSize: cs.fontSize,
          whiteSpace: cs.whiteSpace,
          overflow: cs.overflow,
          width: r.width,
          height: r.height,
          viewport: [window.innerWidth, window.innerHeight]
        };
      })()
    JS
  end

  def assert_peak_title_ok(metrics, expected_text, width, height)
    assert metrics["ok"], "title missing at #{width}x#{height}: #{metrics.inspect}"
    assert_equal expected_text, metrics["text"]
    refute_equal "nowrap", metrics["whiteSpace"].to_s,
                 "still single-line nowrap at #{width}x#{height}: #{metrics.inspect}"
    assert_operator metrics["width"].to_f, :>=, 100,
                    "title too narrow at #{width}x#{height}: #{metrics.inspect}"
    assert_operator metrics["height"].to_f, :>=, 16,
                    "title has no height at #{width}x#{height}: #{metrics.inspect}"
    px = metrics["fontSize"].to_s.to_f
    assert_operator px, :>=, 14.0,
                    "font-size below peak floor at #{width}x#{height}: #{metrics.inspect}"
  end

  def assert_destination_fluid_title(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
    sign_in_user!
    assert_selector ".lp-dash-nav", wait: 8
    visit life_journey_path(@journey.reload, goal_id: @goal.id, plan_id: @plan.id)
    assert_selector "#strategy-world.lp-rpg.is-focus-phase", wait: 10
    assert_no_selector ".lp-first-climb-shell", wait: 2
    assert_selector "#mountain-trail.lp-trail.is-v4", wait: 10
    assert_selector ".lp-trail__peak-title", text: /Become a Rails developer/i, visible: :all, wait: 5
    metrics = title_metrics(".lp-trail__peak-title")
    assert_peak_title_ok(metrics, "Become a Rails developer", width, height)
  end

  def assert_today_climb_band(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
    sign_in_user!
    assert_selector ".lp-dash-nav", wait: 8
    within(".lp-dash-nav") { click_link "Today" }
    assert_selector ".lp-dash-hero", visible: :all, wait: 8
    assert_selector ".lp-dash-hero__avatar-img", visible: :all
    assert_selector ".lp-dash-timeline", visible: :all
    assert_no_selector ".lp-dash-climb"
  end
end
