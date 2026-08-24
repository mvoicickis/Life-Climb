# frozen_string_literal: true

require "application_system_test_case"

# V4 peak pennant is a compact flag (~100–150px). Title must stay readable
# and present — not edge-clipped to a near-zero width.
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
    @plan = plan
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

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_selector "#strategy-world.lp-rpg.is-focus-phase.is-v4-phone", wait: 5
    assert_selector ".lp-trail__peak-title.lp-rpg-destination-carousel__title", visible: :all, wait: 5

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const title = document.querySelector(".lp-trail__peak-title");
        const peak = document.querySelector(".lp-trail__peak");
        const pennant = document.querySelector(".lp-trail__pennant");
        if (!title || !peak) return { ok: false, reason: "missing nodes" };
        const tr = title.getBoundingClientRect();
        const pr = peak.getBoundingClientRect();
        const pennantW = pennant ? pennant.getBoundingClientRect().width : null;
        const titleCenter = tr.left + tr.width / 2;
        const peakCenter = pr.left + pr.width / 2;
        return {
          ok: true,
          text: (title.textContent || "").trim(),
          titleW: tr.width,
          titleH: tr.height,
          pennantW,
          peakW: pr.width,
          centerDelta: Math.abs(titleCenter - peakCenter),
          viewport: [window.innerWidth, window.innerHeight]
        };
      })()
    JS

    assert metrics["ok"], "Destination title metrics missing: #{metrics.inspect}"
    assert_match(/Become a Rails developer/i, metrics["text"].to_s)
    assert_operator metrics["titleW"], :>=, 100,
                    "title edge-clipped (too narrow) at #{width}x#{height}: #{metrics.inspect}"
    assert_operator metrics["titleH"], :>=, 16,
                    "title has no visible height at #{width}x#{height}: #{metrics.inspect}"
    assert_operator metrics["centerDelta"], :<=, 80,
                    "title not near peak at #{width}x#{height}: #{metrics.inspect}"
    assert_no_selector ".lp-rpg-destination-carousel__stage"
    assert_no_selector ".lp-rpg-destination-carousel__arrow"
  end
end
