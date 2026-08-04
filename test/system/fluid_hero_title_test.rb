# frozen_string_literal: true

require "application_system_test_case"

# Destination + Today hero titles use fluid display-lg type and 2-line wrap
# instead of single-line ellipsis truncation.
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
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    plan = @goal.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "plan", title: "Skills path", position: 0
    )
    camp = plan.children.create!(
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
          titleAttr: el.getAttribute("title") || "",
          fontSize: cs.fontSize,
          whiteSpace: cs.whiteSpace,
          webkitLineClamp: cs.webkitLineClamp || cs.lineClamp || "",
          overflow: cs.overflow,
          width: r.width,
          height: r.height,
          viewport: [window.innerWidth, window.innerHeight]
        };
      })()
    JS
  end

  def assert_hero_title_ok(metrics, expected_text, width, height)
    assert metrics["ok"], "title missing at #{width}x#{height}: #{metrics.inspect}"
    assert_equal expected_text, metrics["text"]
    assert_equal expected_text, metrics["titleAttr"]
    refute_equal "nowrap", metrics["whiteSpace"].to_s,
                 "still single-line nowrap at #{width}x#{height}: #{metrics.inspect}"
    assert_includes %w[2], metrics["webkitLineClamp"].to_s,
                    "expected line-clamp 2 at #{width}x#{height}: #{metrics.inspect}"
    assert_operator metrics["width"].to_f, :>=, 120,
                    "title too narrow at #{width}x#{height}: #{metrics.inspect}"
    assert_operator metrics["height"].to_f, :>=, 16,
                    "title has no height at #{width}x#{height}: #{metrics.inspect}"
    px = metrics["fontSize"].to_s.to_f
    assert_operator px, :>=, 18.0,
                    "font-size below fluid floor at #{width}x#{height}: #{metrics.inspect}"
    # Short viewport may use tighter min (1.25rem ≈ 20px); tall uses ≥1.35rem ≈ 21.6px
    if height <= 600
      assert_operator px, :<=, 34.0
    end
  end

  def assert_destination_fluid_title(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
    sign_in_user!
    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector "#strategy-world.lp-rpg.is-focus-phase", wait: 5
    assert_selector ".lp-rpg-destination-carousel__title", visible: :all, wait: 5
    metrics = title_metrics(".lp-rpg-destination-carousel__title")
    assert_hero_title_ok(metrics, "Become a Rails developer", width, height)
  end

  def assert_today_climb_band(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
    sign_in_user!
    within(".lp-dash-nav") { click_link "Today" }
    assert_selector ".lp-dash-climb", visible: :all, wait: 5
    assert_selector ".lp-dash-climb__avatar-img", visible: :all
    assert_selector ".lp-dash-climb__climber", visible: :all
    assert_selector ".lp-dash-battle", visible: :all
    assert_no_selector ".lp-dash-hero"
  end
end
