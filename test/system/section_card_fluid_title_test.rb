# frozen_string_literal: true

require "application_system_test_case"

# Project Sections checkpoint titles use fluid ui-md and a real 2-line wrap
# (not a flex-collapsed single-line ellipsis).
class SectionCardFluidTitleTest < ApplicationSystemTestCase
  LONG_TITLE = "Start: Make LifePoints Successful"

  setup do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship the product",
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Design",
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
    @section = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: LONG_TITLE, position: 0
    )
    practice_leaf_for!(@section).children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Design", scheduled_on: Date.current, position: 0
    )
  end

  test "section card title wraps two lines on tall phone" do
    assert_section_title_fluid(390, 844)
  end

  test "section card title wraps two lines on short phone" do
    assert_section_title_fluid(390, 568)
  end

  private

  def sign_in_user!
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
  end

  def title_metrics
    page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector(".lp-rpg-section-card.is-current .lp-rpg-section-card__title");
        const card = document.querySelector(".lp-rpg-section-card.is-current");
        if (!el || !card) return { ok: false, reason: "missing" };
        const cs = getComputedStyle(el);
        const r = el.getBoundingClientRect();
        const cardR = card.getBoundingClientRect();
        const fontPx = parseFloat(cs.fontSize) || 0;
        const lineHeightPx = (() => {
          const raw = cs.lineHeight;
          if (!raw || raw === "normal") return fontPx * 1.25;
          const n = parseFloat(raw);
          return Number.isFinite(n) ? n : fontPx * 1.25;
        })();
        return {
          ok: true,
          text: (el.textContent || "").trim(),
          titleAttr: el.getAttribute("title") || "",
          fontSize: cs.fontSize,
          fontPx,
          lineHeightPx,
          whiteSpace: cs.whiteSpace,
          webkitLineClamp: cs.webkitLineClamp || cs.lineClamp || "",
          alignItemsLink: getComputedStyle(el.parentElement).alignItems,
          width: r.width,
          height: r.height,
          cardHeight: cardR.height,
          viewport: [window.innerWidth, window.innerHeight]
        };
      })()
    JS
  end

  def assert_section_title_fluid(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
    sign_in_user!
    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @section.id)
    assert_selector "#strategy-world.lp-rpg.is-focus-phase", wait: 5
    assert_selector ".lp-rpg-section-card.is-current .lp-rpg-section-card__title", visible: :all, wait: 5

    metrics = title_metrics
    assert metrics["ok"], "section title missing at #{width}x#{height}: #{metrics.inspect}"
    assert_equal LONG_TITLE, metrics["text"]
    assert_equal LONG_TITLE, metrics["titleAttr"]
    refute_equal "nowrap", metrics["whiteSpace"].to_s,
                 "title still nowrap at #{width}x#{height}: #{metrics.inspect}"
    assert_includes %w[2], metrics["webkitLineClamp"].to_s,
                    "expected line-clamp 2 at #{width}x#{height}: #{metrics.inspect}"
    assert_equal "flex-start", metrics["alignItemsLink"].to_s,
                 "link row must top-align so 2-line clamp can grow: #{metrics.inspect}"

    font_px = metrics["fontPx"].to_f
    # ui-md floor is 0.84rem ≈ 13.44px
    assert_operator font_px, :>=, 13.0,
                    "font-size below ui-md floor at #{width}x#{height}: #{metrics.inspect}"
    assert_operator font_px, :<=, 16.0,
                    "font-size above ui-md ceiling at #{width}x#{height}: #{metrics.inspect}"

    # Two full lines: height should clear ~1.6× line-height (not a single-line collapse).
    line_h = metrics["lineHeightPx"].to_f
    assert_operator metrics["height"].to_f, :>=, line_h * 1.6,
                    "title height looks like 1 line at #{width}x#{height}: #{metrics.inspect}"
    assert_operator metrics["cardHeight"].to_f, :>=, 7.5 * 16,
                    "card too short for 2-line title at #{width}x#{height}: #{metrics.inspect}"
  end
end
