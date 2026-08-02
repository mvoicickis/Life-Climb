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
    practice_leaf_for!(camps[1]).children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Design battle card",
      description: "Wire the planning card",
      scheduled_on: Date.current, position: 0
    )
    @current = camps[1]
  end

  test "short phone keeps Practice Category focus and Open in Today in viewport" do
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
    assert_selector ".lp-rpg-breadcrumbs", visible: :all
    assert_selector ".lp-rpg-section-card", minimum: 2, wait: 5
    title_metrics = page.evaluate_script(<<~JS)
      (() => {
        const t = document.querySelector(".lp-rpg-destination-carousel__title");
        const r = t.getBoundingClientRect();
        return { w: r.width, h: r.height, text: (t.textContent || "").trim() };
      })()
    JS
    assert_match(/Ship the MVP/i, title_metrics["text"])
    assert_operator title_metrics["w"], :>=, 120, "Destination title too narrow: #{title_metrics.inspect}"
    assert_selector ".lp-rpg-practice-focus.is-entered .lp-rpg-practice-focus__title", text: /Daily battles/i
    assert_selector ".lp-rpg-practice-row__title", text: /Design battle card/i, visible: :all, wait: 5
    assert_selector ".lp-rpg-todays-practice__kicker", text: /Today's Practice/i
    assert_no_selector ".lp-rpg-stat.is-mountain"
    assert_no_text(/you are here · \d+%/i)
    assert_selector ".lp-rpg-breadcrumbs__item", text: /MVP path/i
    assert_no_selector "form[action*='battle_win']"

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/practice-category-focus-568px.png")

    assert_selector ".lp-rpg-practice-focus__cta", text: /Open in Today/i, visible: :all
    assert_selector ".lp-rpg-practice-add", text: /Add Practice/i, visible: :all
    page.save_screenshot("/opt/cursor/artifacts/screenshots/practice-category-focus-cta-568px.png")

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const root = document.querySelector('.lp-rpg.is-focus-phase');
        const trail = document.querySelector('.lp-rpg__stage-sections');
        const battle = document.querySelector('.lp-rpg__stage-battle');
        const practice = document.querySelector('.lp-rpg-practice-focus.is-entered .lp-rpg-practice-row');
        const chrome = document.querySelector('.lp-rpg__chrome-top');
        const stage = document.querySelector('.lp-rpg__stage');
        const stats = document.querySelector('.lp-rpg__chrome-bottom, .lp-rpg-stats');
        const visible = Array.from(document.querySelectorAll('.lp-rpg-section-card')).length;
        const rootStyle = root ? getComputedStyle(root) : null;
        const htmlStyle = getComputedStyle(document.documentElement);
        const chromePad = chrome ? getComputedStyle(chrome).paddingLeft : '';
        const stagePad = stage ? getComputedStyle(stage).paddingLeft : '';
        const practiceRect = practice ? practice.getBoundingClientRect() : null;
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
          trailH: trail ? Math.round(trail.getBoundingClientRect().height) : 0,
          battleH: battle ? Math.round(battle.getBoundingClientRect().height) : 0,
          practiceVisible: !!(practiceRect && practiceRect.height > 8 && practiceRect.top < window.innerHeight && practiceRect.bottom > 0),
          statsPresent: !!stats,
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
    assert_equal true, metrics["practiceVisible"], "Today's Practice row should stay in viewport: #{metrics.inspect}"
    assert_equal false, metrics["statsPresent"], "bottom XP/streak/glow strip should be gone: #{metrics.inspect}"
    assert_equal metrics["chromePad"], metrics["stagePad"], "chrome/stage gutters should match: #{metrics.inspect}"
    assert_equal metrics["chromePad"], metrics["statsPad"], "chrome/stats gutters should match: #{metrics.inspect}"

    assert File.exist?("/opt/cursor/artifacts/screenshots/practice-category-focus-568px.png")
    assert File.exist?("/opt/cursor/artifacts/screenshots/practice-category-focus-cta-568px.png")
  end
end
