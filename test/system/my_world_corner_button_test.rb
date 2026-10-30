# frozen_string_literal: true

require "application_system_test_case"

# Corner My world entry stays on screen and clear of the camps-ahead map sign.
class MyWorldCornerButtonTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Learn German to B1 level",
      ideal_scene: "Conversational",
      current_reality: "Studying",
      next_win: "A2 exam",
      today_mission: "Vocabulary drill",
      closer_percent: 30,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ], character: "fox")
    @journey = @user.reload.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "plan", title: "Language path", position: 0
    )
    %w[Basics Grammar Listening Speaking].each_with_index do |title, i|
      @plan.children.create!(
        user: @user, life_area: @journey.life_area, life_journey: @journey,
        horizon: "project", title: title, position: i
      )
    end
  end

  test "corner button clear of map sign at 320x568" do
    assert_corner_clear_of_map_sign(320, 568)
  end

  test "corner button clear of map sign at 360x640" do
    assert_corner_clear_of_map_sign(360, 640)
  end

  private

  def assert_corner_clear_of_map_sign(width, height)
    page.driver.browser.manage.window.resize_to(width, height)

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 8

    visit life_journey_path(@journey.reload, goal_id: @goal.id, plan_id: @plan.id)
    assert_selector "#mountain-trail.lp-trail.is-v4", wait: 10
    assert_selector "a.lp-trail__my-world-corner[href='#{world_path}']", wait: 5
    assert_selector ".lp-trail-map-sign", visible: :all, wait: 5
    assert_no_selector ".lp-trail__summit .lp-trail__my-world-corner", visible: :all
    assert_no_selector ".lp-trail__summit .lp-trail__my-world-pill", visible: :all

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const corner = document.querySelector("a.lp-trail__my-world-corner");
        const more = document.querySelector(".lp-trail-map-sign");
        if (!corner || !more) return { ok: false, reason: "missing nodes" };

        const c = corner.getBoundingClientRect();
        const m = more.getBoundingClientRect();
        const gap = 8;
        const overlaps = !(
          c.right < m.left - gap ||
          c.left > m.right + gap ||
          c.bottom < m.top - gap ||
          c.top > m.bottom + gap
        );
        const onScreen =
          c.left >= 0 &&
          c.top >= 0 &&
          c.right <= window.innerWidth + 0.5 &&
          c.bottom <= window.innerHeight + 0.5;

        return {
          ok: true,
          overlaps,
          onScreen,
          corner: { top: c.top, bottom: c.bottom, left: c.left, right: c.right },
          more: { top: m.top, bottom: m.bottom, left: m.left, right: m.right },
          viewport: [window.innerWidth, window.innerHeight]
        };
      })()
    JS

    assert metrics["ok"], "Corner metrics missing at #{width}x#{height}: #{metrics.inspect}"
    assert metrics["onScreen"],
           "My world corner off screen at #{width}x#{height}: #{metrics.inspect}"
    assert_not metrics["overlaps"],
               "My world corner overlaps map sign at #{width}x#{height}: #{metrics.inspect}"
  end
end
