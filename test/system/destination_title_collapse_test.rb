# frozen_string_literal: true

require "application_system_test_case"

# Destination stage must stay one full-width column whenever peeks leave the grid.
# A leftover 14%|1fr|14% track parks .active in ~50px and edge-clips the title.
class DestinationTitleCollapseTest < ApplicationSystemTestCase
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

  test "destination title stays centered on tall iPhone viewport" do
    assert_destination_title_centered(390, 844)
  end

  test "destination title stays centered on short phone viewport" do
    assert_destination_title_centered(390, 568)
  end

  private

  def assert_destination_title_centered(width, height)
    page.driver.browser.manage.window.resize_to(width, height)

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"

    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector "#strategy-world.lp-rpg.is-focus-phase", wait: 5
    assert_selector ".lp-rpg-destination-carousel__title", visible: :all, wait: 5

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const title = document.querySelector(".lp-rpg-destination-carousel__title");
        const stage = document.querySelector(".lp-rpg-destination-carousel__stage");
        const active = document.querySelector(".lp-rpg-destination-carousel__active");
        const row = document.querySelector(".lp-rpg-destination-carousel__title-row");
        if (!title || !stage || !active) return { ok: false, reason: "missing nodes" };
        const tr = title.getBoundingClientRect();
        const sr = stage.getBoundingClientRect();
        const ar = active.getBoundingClientRect();
        const rr = row ? row.getBoundingClientRect() : null;
        const stageStyle = getComputedStyle(stage);
        const titleCenter = tr.left + tr.width / 2;
        const stageCenter = sr.left + sr.width / 2;
        return {
          ok: true,
          text: (title.textContent || "").trim(),
          titleW: tr.width,
          titleH: tr.height,
          titleLeft: tr.left,
          rowW: rr ? rr.width : null,
          activeW: ar.width,
          stageW: sr.width,
          centerDelta: Math.abs(titleCenter - stageCenter),
          stageCols: stageStyle.gridTemplateColumns,
          viewport: [window.innerWidth, window.innerHeight]
        };
      })()
    JS

    assert metrics["ok"], "Destination title metrics missing: #{metrics.inspect}"
    assert_match(/Become a Rails developer/i, metrics["text"].to_s)
    assert_operator metrics["titleW"], :>=, 120,
                    "title edge-clipped (too narrow) at #{width}x#{height}: #{metrics.inspect}"
    assert_operator metrics["titleH"], :>=, 16,
                    "title has no visible height at #{width}x#{height}: #{metrics.inspect}"
    assert_operator metrics["activeW"], :>=, metrics["stageW"] * 0.7,
                    "active not full stage width at #{width}x#{height}: #{metrics.inspect}"
    assert_operator metrics["centerDelta"], :<=, 24,
                    "title not centered in stage at #{width}x#{height}: #{metrics.inspect}"
    refute_match(/\d+(\.\d+)?%/, metrics["stageCols"].to_s,
                 "stage still uses %-based multi columns while peeks may be gone: #{metrics.inspect}")
  end
end
