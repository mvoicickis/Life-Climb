# frozen_string_literal: true

require "application_system_test_case"

# Path chips keep compact --lp-path-card width but wrap titles to 2 lines
# so realistic plan names stay readable without overlapping chrome.
class PathChipFluidTitleTest < ApplicationSystemTestCase
  LONG_TITLE = "Make LifePoints Successsull"
  SHORT_TITLE = "Learn German"

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
  end

  test "long path title is fully readable without chrome overlap" do
    plan = create_plan!(LONG_TITLE)
    assert_path_title_readable(plan, LONG_TITLE, 390, 844)
  end

  test "short path title is fully readable without chrome overlap" do
    plan = create_plan!(SHORT_TITLE)
    assert_path_title_readable(plan, SHORT_TITLE, 390, 844)
  end

  private

  def create_plan!(title)
    plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: title, position: 0
    )
    camp = plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Camp", position: 0
    )
    practice_leaf_for!(camp).children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Design", scheduled_on: Date.current, position: 0
    )
    plan
  end

  def sign_in_user!
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
  end

  def path_metrics
    page.evaluate_script(<<~JS)
      (() => {
        const title = document.querySelector(".lp-rpg-path.is-focus .lp-rpg-path__title");
        const path = document.querySelector(".lp-rpg-path.is-focus");
        const item = document.querySelector(".lp-rpg-plan-rail__item.is-focus");
        const menu = item?.querySelector(".lp-rpg-path__menu-btn");
        const dest = document.querySelector(".lp-rpg-destination-carousel__title");
        const trail = document.querySelector(".lp-rpg__stage-trail, .lp-rpg-trail, .lp-climb-path");
        if (!title || !path || !item) return { ok: false, reason: "missing" };
        const cs = getComputedStyle(title);
        const tr = title.getBoundingClientRect();
        const pr = path.getBoundingClientRect();
        const ir = item.getBoundingClientRect();
        const mr = menu?.getBoundingClientRect();
        const dr = dest?.getBoundingClientRect();
        const trailR = trail?.getBoundingClientRect();
        const truncated = title.scrollHeight > title.clientHeight + 1;
        // Menu sits top-right; titles may share Y-range — only horizontal intrusion counts.
        const menuOverlapsTitle = !!(mr && tr.right > mr.left + 2 && tr.left < mr.right - 2);
        return {
          ok: true,
          text: (title.textContent || "").trim(),
          titleAttr: title.getAttribute("title") || "",
          whiteSpace: cs.whiteSpace,
          webkitLineClamp: cs.webkitLineClamp || cs.lineClamp || "",
          fontSize: cs.fontSize,
          pathWidth: pr.width,
          itemWidth: ir.width,
          titleWidth: tr.width,
          truncated,
          menuOverlapsTitle,
          destBottom: dr ? dr.bottom : null,
          pathTop: pr.top,
          pathBottom: pr.bottom,
          trailTop: trailR ? trailR.top : null,
          pathCardMax: getComputedStyle(document.documentElement).getPropertyValue("--lp-path-card") ||
            getComputedStyle(document.querySelector(".lp-rpg-plan-rail")).getPropertyValue("--lp-path-card"),
          viewport: [window.innerWidth, window.innerHeight]
        };
      })()
    JS
  end

  def assert_path_title_readable(plan, expected_text, width, height)
    page.driver.browser.manage.window.resize_to(width, height)
    sign_in_user!
    assert_selector ".lp-dash-nav", wait: 5
    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: plan.id)
    assert_selector "#strategy-world.lp-rpg.is-focus-phase", wait: 10
    assert_selector ".lp-rpg-path.is-focus .lp-rpg-path__title", text: expected_text, visible: :all, wait: 5

    assert_text expected_text

    metrics = path_metrics
    assert metrics["ok"], "path title missing at #{width}x#{height}: #{metrics.inspect}"
    assert_equal expected_text, metrics["text"]
    assert_equal expected_text, metrics["titleAttr"]
    refute_equal "nowrap", metrics["whiteSpace"].to_s
    assert_includes %w[2], metrics["webkitLineClamp"].to_s

    # Chip width stays compact (~7.5rem = 120px); do not widen the rail card.
    assert_operator metrics["itemWidth"].to_f, :<=, 130.0,
                    "path chip widened beyond compact size: #{metrics.inspect}"
    assert_operator metrics["itemWidth"].to_f, :>=, 100.0,
                    "path chip unexpectedly narrow: #{metrics.inspect}"

    refute metrics["truncated"],
           "path title still visually truncated: #{metrics.inspect}"
    refute metrics["menuOverlapsTitle"],
           "title overlaps ⋮ menu: #{metrics.inspect}"

    if metrics["destBottom"]
      assert_operator metrics["pathTop"].to_f, :>=, metrics["destBottom"].to_f - 1,
                      "path overlaps Destination title: #{metrics.inspect}"
    end
    if metrics["trailTop"]
      assert_operator metrics["pathBottom"].to_f, :<=, metrics["trailTop"].to_f + 2,
                      "path overlaps trail/sections below: #{metrics.inspect}"
    end
  end
end
