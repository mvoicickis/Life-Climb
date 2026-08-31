# frozen_string_literal: true

require "application_system_test_case"

# V4 dropped path chips. Multi-plan titles appear as HUD plan links;
# destination title stays on the peak pennant.
class PathChipFluidTitleTest < ApplicationSystemTestCase
  LONG_TITLE = "Make LifePoints Successsull"
  SHORT_TITLE = "Learn German"

  setup do
    @user = users(:one)
    allow_extra_climbs!(@user)
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
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ], character: "fox")
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
  end

  test "long path title is fully readable without chrome overlap" do
    plan = create_plan!(LONG_TITLE)
    create_plan!("Other Path", position: 1)
    assert_path_title_readable(plan, LONG_TITLE, 390, 844)
  end

  test "short path title is fully readable without chrome overlap" do
    plan = create_plan!(SHORT_TITLE)
    create_plan!("Other Path", position: 1)
    assert_path_title_readable(plan, SHORT_TITLE, 390, 844)
  end

  private

  def create_plan!(title, position: 0)
    plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: title, position: position
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

  def path_metrics(expected_text)
    needle = expected_text.to_s.split.first.to_json
    page.evaluate_script(<<~JS)
      (() => {
        const needle = #{needle};
        const link = Array.from(document.querySelectorAll(".lp-trail-hud__plan")).find((el) =>
          (el.textContent || "").includes(needle)
        ) || document.querySelector(".lp-trail-hud__plan.is-active");
        const peak = document.querySelector(".lp-trail__peak-title");
        if (!link && !peak) return { ok: false, reason: "missing" };
        const target = link || peak;
        const cs = getComputedStyle(target);
        const tr = target.getBoundingClientRect();
        return {
          ok: true,
          text: (target.textContent || "").trim(),
          whiteSpace: cs.whiteSpace,
          fontSize: cs.fontSize,
          titleWidth: tr.width,
          titleHeight: tr.height,
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
    assert_selector "#strategy-world.lp-rpg.is-focus-phase.is-v4-phone", wait: 10
    assert_no_selector ".lp-rpg-path"
    assert_selector ".lp-trail-hud__plan.is-active", wait: 5

    metrics = path_metrics(expected_text)
    assert metrics["ok"], "HUD/peak title missing at #{width}x#{height}: #{metrics.inspect}"
    # HUD truncates long plan names to HUD_PLAN_TITLE_LIMIT chars in the link text.
    assert_includes metrics["text"], expected_text[0, 20]
    assert_operator metrics["titleWidth"].to_f, :>=, 40.0,
                    "plan/peak title unexpectedly narrow: #{metrics.inspect}"
    assert_operator metrics["titleHeight"].to_f, :>=, 12.0,
                    "plan/peak title has no height: #{metrics.inspect}"
    assert_selector ".lp-trail__peak-title", text: /Ship the product/i
  end
end
