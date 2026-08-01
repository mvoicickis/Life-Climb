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
      horizon: "day", title: "Design battle card",
      description: "Wire the planning card",
      scheduled_on: Date.current, position: 0
    )
    @current = camps[1]
  end

  test "short phone keeps page locked and Today's Plan in viewport" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector "#strategy-world", wait: 5

    visit life_journey_path(@journey.reload, goal_id: @goal.id, plan_id: @plan.id, focus_id: @current.id)
    assert_selector "#strategy-world.lp-rpg.is-focus-phase", wait: 5
    assert_no_selector ".lp-first-climb-shell"

    assert_selector ".lp-rpg__stage.is-planning", visible: :all
    assert_selector ".lp-rpg-sheet.is-planning", visible: :all
    assert_selector ".lp-rpg-current-path", visible: :all
    assert_selector ".lp-rpg-node.is-window-visible", minimum: 2, wait: 5
    assert_text(/Daily battles/i)
    assert_selector ".lp-rpg-plan-card__title", text: /Design battle card/i, visible: :all, wait: 5
    assert_no_selector ".lp-rpg-stat.is-mountain"
    assert_no_text(/you are here ·/i)
    assert_no_selector "form[action*='battle_win']"

    find(".lp-rpg-plan-card__summary", text: /Design battle card/i).click
    assert_selector ".lp-rpg-plan-card[open] .lp-rpg-plan-card__cta", text: /Open in Today/i, wait: 3
    assert_text(/Wire the planning card/i)

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const root = document.querySelector('.lp-rpg.is-focus-phase');
        const trail = document.querySelector('.lp-rpg__stage-trail');
        const battle = document.querySelector('.lp-rpg__stage-battle');
        const planCard = document.querySelector('.lp-rpg-plan-card');
        const chrome = document.querySelector('.lp-rpg__chrome-top');
        const stage = document.querySelector('.lp-rpg__stage');
        const stats = document.querySelector('.lp-rpg__chrome-bottom');
        const visible = Array.from(document.querySelectorAll('[data-trail-window-target="node"]'))
          .filter((n) => !n.hidden && n.classList.contains('is-window-visible')).length;
        const rootStyle = root ? getComputedStyle(root) : null;
        const htmlStyle = getComputedStyle(document.documentElement);
        const chromePad = chrome ? getComputedStyle(chrome).paddingLeft : '';
        const stagePad = stage ? getComputedStyle(stage).paddingLeft : '';
        const statsPad = stats ? getComputedStyle(stats).paddingLeft : '';
        const planRect = planCard ? planCard.getBoundingClientRect() : null;
        const statsR = stats ? stats.getBoundingClientRect() : null;
        window.scrollTo(0, 200);
        const scrolled = window.scrollY || document.documentElement.scrollTop || 0;
        window.scrollTo(0, 0);
        return {
          visible,
          innerHeight: window.innerHeight,
          rootOverflow: rootStyle ? rootStyle.overflowY || rootStyle.overflow : '',
          htmlOverflow: htmlStyle.overflowY || htmlStyle.overflow,
          chromePad,
          stagePad,
          statsPad,
          trailH: trail ? Math.round(trail.getBoundingClientRect().height) : 0,
          battleH: battle ? Math.round(battle.getBoundingClientRect().height) : 0,
          planVisible: !!(planRect && planRect.height > 8 && planRect.top < window.innerHeight && planRect.bottom > 0),
          statsInView: !!(statsR && statsR.top < window.innerHeight && statsR.bottom > 0),
          pageScrolled: scrolled > 1
        };
      })()
    JS
    assert_operator metrics["visible"], :<=, 3
    assert_operator metrics["visible"], :>=, 2
    assert_operator metrics["trailH"], :>=, 28, "trail glance too short at 568px: #{metrics.inspect}"
    assert_operator metrics["battleH"], :>=, 88, "planning stage too short at 568px: #{metrics.inspect}"
    assert_includes %w[hidden clip], metrics["rootOverflow"]
    assert_includes %w[hidden clip], metrics["htmlOverflow"]
    assert_equal false, metrics["pageScrolled"], "page should refuse scroll at 568px: #{metrics.inspect}"
    assert_operator metrics["battleH"], :>, metrics["trailH"]
    assert_equal true, metrics["planVisible"], "Today's Plan card should stay in viewport: #{metrics.inspect}"
    assert_equal true, metrics["statsInView"], "stats strip should stay in viewport: #{metrics.inspect}"
    assert_equal metrics["chromePad"], metrics["stagePad"], "chrome/stage gutters should match: #{metrics.inspect}"
    assert_equal metrics["chromePad"], metrics["statsPad"], "chrome/stats gutters should match: #{metrics.inspect}"

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    path = "/opt/cursor/artifacts/screenshots/mountain-planning-center-568px.png"
    page.save_screenshot(path)
    assert File.exist?(path), "expected screenshot at #{path}"
  end
end
