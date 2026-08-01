# frozen_string_literal: true

require "application_system_test_case"

class FixedViewportMountainSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    # Short phone (iPhone SE class)
    page.driver.browser.manage.window.resize_to(390, 568)

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
    camps = [
      "Authentication",
      "Daily battles",
      "Dashboard",
      "Notifications"
    ].each_with_index.map do |title, i|
      @plan.children.create!(
        user: @user, life_area: @area, life_journey: @journey,
        horizon: "project", title: title, position: i
      )
    end
    camps[0].complete!
    camps[1].children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Design battle card", scheduled_on: Date.current, position: 0
    )
    @current = camps[1]
  end

  test "short phone keeps page locked and trail legible at 32-36 percent stage" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector "#strategy-world", wait: 5

    # Focus the camp with today's battle so the Now rail is populated.
    visit life_journey_path(@journey.reload, goal_id: @goal.id, plan_id: @plan.id, focus_id: @current.id)
    assert_selector "#strategy-world.lp-rpg.is-focus-phase", wait: 5
    assert_no_selector ".lp-first-climb-shell"

    assert_selector ".lp-rpg__stage-trail", visible: :all
    assert_selector ".lp-rpg-sheet.is-dominant", visible: :all
    assert_selector ".lp-rpg-node.is-window-visible", minimum: 2, wait: 5
    assert_text(/Daily battles/i)
    assert_selector ".lp-rpg-now-card__title", text: /Design battle card/i, visible: :all, wait: 5
    assert_selector ".lp-rpg-node.is-current em", text: /you are here/i, visible: :all

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const root = document.querySelector('.lp-rpg.is-focus-phase');
        const trail = document.querySelector('.lp-rpg__stage-trail');
        const battle = document.querySelector('.lp-rpg__stage-battle');
        const visible = Array.from(document.querySelectorAll('[data-trail-window-target="node"]'))
          .filter((n) => !n.hidden && n.classList.contains('is-window-visible')).length;
        const rootStyle = root ? getComputedStyle(root) : null;
        const htmlStyle = getComputedStyle(document.documentElement);
        const bodyStyle = getComputedStyle(document.body);
        window.scrollTo(0, 200);
        const scrolled = window.scrollY || document.documentElement.scrollTop || 0;
        window.scrollTo(0, 0);
        return {
          visible,
          innerHeight: window.innerHeight,
          rootOverflow: rootStyle ? rootStyle.overflowY || rootStyle.overflow : '',
          htmlOverflow: htmlStyle.overflowY || htmlStyle.overflow,
          bodyOverflow: bodyStyle.overflowY || bodyStyle.overflow,
          trailH: trail ? Math.round(trail.getBoundingClientRect().height) : 0,
          battleH: battle ? Math.round(battle.getBoundingClientRect().height) : 0,
          pageScrolled: scrolled > 1
        };
      })()
    JS
    assert_operator metrics["visible"], :<=, 3
    assert_operator metrics["visible"], :>=, 2
    assert_operator metrics["trailH"], :>=, 48, "trail stage too short at 568px: #{metrics.inspect}"
    assert_operator metrics["battleH"], :>=, 96, "battle stage too short at 568px: #{metrics.inspect}"
    assert_includes %w[hidden clip], metrics["rootOverflow"]
    assert_includes %w[hidden clip], metrics["htmlOverflow"]
    assert_equal false, metrics["pageScrolled"], "page should refuse scroll at 568px: #{metrics.inspect}"
    # Battle gets the larger stage share (dominant).
    assert_operator metrics["battleH"], :>, metrics["trailH"]

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    path = "/opt/cursor/artifacts/screenshots/mountain-568px.png"
    page.save_screenshot(path)
    assert File.exist?(path), "expected screenshot at #{path}"
  end
end
