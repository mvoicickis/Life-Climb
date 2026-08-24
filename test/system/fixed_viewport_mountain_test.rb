# frozen_string_literal: true

require "application_system_test_case"

class FixedViewportMountainSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
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
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ], character: "fox")
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
    @leaf = practice_leaf_for!(camps[1])
    host = Strategy::EnsureFolderQuest.call(folder: @leaf)
    host.practice_tasks.create!(
      user: @user, title: "Design battle card", position: 0
    )
    @current = @leaf
  end

  test "short phone keeps the project list in the planning viewport" do
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
    assert_selector ".lp-rpg__stage-trail", visible: :all
    assert_no_selector ".lp-rpg-sheet.is-quest-space"
    assert_no_selector ".lp-rpg__stage-battle"
    assert_no_selector ".lp-rpg-breadcrumbs"
    open_mountain_list_fallback!
    assert_selector ".lp-climb-path__project", minimum: 4, visible: :all, wait: 5
    title_metrics = page.evaluate_script(<<~JS)
      (() => {
        const t = document.querySelector(".lp-rpg-destination-carousel__title");
        const r = t.getBoundingClientRect();
        return { w: r.width, h: r.height, text: (t.textContent || "").trim() };
      })()
    JS
    assert_match(/Ship the MVP/i, title_metrics["text"])
    assert_operator title_metrics["w"], :>=, 120, "Destination title too narrow: #{title_metrics.inspect}"
    assert_selector "#climb-path-project-#{@current.id} .lp-climb-path__title", text: /Daily battles/i, visible: :all
    assert_no_selector ".lp-rpg-camp-switch"
    assert_no_selector ".lp-rpg-stat.is-mountain"
    assert_no_text(/you are here · \d+%/i)
    assert_no_selector ".lp-rpg-section-head"
    # Battle win lives in the V4 camp sheet, not the old stage battle pane.
    assert_selector "#trail-sheet-body form[action*='battle_win']", visible: :all
    assert_no_selector ".lp-rpg__stage-battle form[action*='battle_win']"

    open_project_objectives(@current)
    within("dialog#section-objectives-#{@current.id}") do
      assert_selector ".lp-climb-path__quest-title", text: /Daily battles/i
      assert_selector ".lp-qs-obj__text[value='Design battle card']", visible: :all, wait: 5
      assert_selector ".lp-climb-path__quest-add-input", visible: :all
    end

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/practice-category-focus-568px.png")

    assert_no_selector ".lp-rpg-camp-folder__cta", text: /Begin Today's Battles/i
    assert_no_selector ".lp-rpg-practice-add", text: /Prepare New Quest/i
    page.save_screenshot("/opt/cursor/artifacts/screenshots/practice-category-focus-cta-568px.png")

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const root = document.querySelector('.lp-rpg.is-focus-phase');
        const trail = document.querySelector('.lp-rpg__stage-trail, .lp-rpg__stage-sections');
        const stage = document.querySelector('.lp-rpg__stage.is-planning');
        const chrome = document.querySelector('.lp-rpg__chrome-top');
        const stats = document.querySelector('.lp-rpg__chrome-bottom, .lp-rpg-stats');
        const visible = Array.from(document.querySelectorAll('.lp-climb-path__project')).filter((el) => {
          const r = el.getBoundingClientRect();
          return r.width > 8 && r.height > 8 && r.right > 0 && r.left < window.innerWidth;
        }).length;
        const rootStyle = root ? getComputedStyle(root) : null;
        const htmlStyle = getComputedStyle(document.documentElement);
        const chromePad = chrome ? getComputedStyle(chrome).paddingLeft : '';
        const stagePad = stage ? getComputedStyle(stage).paddingLeft : '';
        return {
          visible,
          innerHeight: window.innerHeight,
          rootOverflow: rootStyle ? rootStyle.overflowY || rootStyle.overflow : '',
          htmlOverflow: htmlStyle.overflowY || htmlStyle.overflow,
          bodyOverflow: getComputedStyle(document.body).overflowY || getComputedStyle(document.body).overflow,
          chromePad,
          stagePad,
          trailH: trail ? Math.round(trail.getBoundingClientRect().height) : 0,
          stageH: stage ? Math.round(stage.getBoundingClientRect().height) : 0,
          statsPresent: !!stats
        };
      })()
    JS
    assert_operator metrics["visible"], :>=, 1
    assert_operator metrics["trailH"], :>=, 28, "climb path trail too short at 568px: #{metrics.inspect}"
    assert_operator metrics["stageH"], :>=, 88, "planning stage too short at 568px: #{metrics.inspect}"
    assert_includes %w[hidden clip], metrics["rootOverflow"]
    assert_includes %w[hidden clip], metrics["htmlOverflow"]
    assert_includes %w[hidden clip], metrics["bodyOverflow"]
    assert_equal false, metrics["statsPresent"], "bottom XP/streak/glow strip should be gone: #{metrics.inspect}"
    assert_equal metrics["chromePad"], metrics["stagePad"], "chrome/stage gutters should match: #{metrics.inspect}"

    assert File.exist?("/opt/cursor/artifacts/screenshots/practice-category-focus-568px.png")
    assert File.exist?("/opt/cursor/artifacts/screenshots/practice-category-focus-cta-568px.png")
  end
end
