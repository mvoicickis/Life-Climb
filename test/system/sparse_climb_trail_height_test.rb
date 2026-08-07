# frozen_string_literal: true

require "application_system_test_case"

# Sparse journeys must not reserve a large empty zone below the last climb CTA.
# Quests stay open (real Mountain state) — do not collapse <details> before measuring.
class SparseClimbTrailHeightTest < ApplicationSystemTestCase
  PHONE_W = 390
  PHONE_H = 844

  setup do
    @user = users(:one)
    @user.update!(character: "fox", support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    lock_phone_viewport!(PHONE_W, PHONE_H)

    Onboarding::Run.call(
      user: @user, area_key: "career", title: "Ship LifePoints",
      ideal_scene: "App live", current_reality: "Building", next_win: "Launch",
      today_mission: "Write tests", closer_percent: 20, route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Learn German", position: 0
    )
    @camp = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Duolingo", position: 0
    )
    leaf = practice_leaf_for!(@camp, title: "Steps")
    host = Strategy::EnsureFolderQuest.call(folder: leaf)
    host.practice_tasks.create!(user: @user, title: "Do a lesson", position: 0)
  end

  test "sparse climb content ends near the nav with quests open" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp.id)
    assert_selector ".lp-climb-path", wait: 5
    assert_selector ".lp-climb-path__quests[open]", wait: 5
    assert_selector ".lp-climb-path__new-btn", wait: 5

    metrics = measure_mountain_layout!
    File.write("/tmp/sparse-climb-after.json", JSON.pretty_generate(metrics))

    assert_equal PHONE_W, metrics["vw"], "viewport width must match resize_to: #{metrics.inspect}"
    assert_equal PHONE_H, metrics["vh"], "viewport height must match resize_to: #{metrics.inspect}"
    assert_includes %w[hidden clip], metrics["rootOverflow"]
    assert_includes %w[hidden clip], metrics["htmlOverflow"]
    assert_includes %w[hidden clip], metrics["bodyOverflow"]
    assert_in_delta metrics["vh"], metrics["rootHeight"], 2.0
    assert_equal "auto", metrics["trailOverflowY"]
    assert metrics["questsOpen"], "selected camp quests must stay open: #{metrics.inspect}"

    # No large empty reserved zone inside stage/trail below the last CTA.
    assert_operator metrics["emptyBelowInTrail"], :<=, 40,
                    "trail empty below New Project too large: #{metrics.inspect}"
    assert_operator metrics["emptyBelowInStage"], :<=, 40,
                    "stage empty below New Project too large: #{metrics.inspect}"
    assert_operator metrics["gapToNav"], :<=, 40,
                    "gap from New Project to bottom nav too large: #{metrics.inspect}"

    # Stage/planning hug content instead of claiming the leftover viewport floor.
    assert_operator metrics["stageH"], :<=, metrics["pathH"] + 48,
                    "stage should size to climb content: #{metrics.inspect}"
    assert_operator metrics["trailH"], :<=, metrics["pathH"] + 24,
                    "trail should size to climb content: #{metrics.inspect}"
  end

  test "dense climb path still scrolls inside the fixed 100dvh shell" do
    # Path helper shows all done + current + a small locked cap — seed many dones.
    @camp.update!(position: 8)
    8.times do |i|
      done = @plan.children.create!(
        user: @user, life_area: @area, life_journey: @journey,
        horizon: "project", title: "Done Camp #{i + 1}", position: i
      )
      done.complete!
    end
    2.times do |i|
      @plan.children.create!(
        user: @user, life_area: @area, life_journey: @journey,
        horizon: "project", title: "Locked Camp #{i + 1}", position: 9 + i
      )
    end

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp.id)
    # Entrance animation may leave off-screen nodes at opacity 0.
    assert_selector ".lp-climb-path__node.is-done", minimum: 6, wait: 5, visible: :all

    metrics = measure_mountain_layout!
    File.write("/tmp/dense-climb-after.json", JSON.pretty_generate(metrics))

    assert_equal PHONE_W, metrics["vw"]
    assert_equal PHONE_H, metrics["vh"]
    assert_includes %w[hidden clip], metrics["rootOverflow"]
    assert_includes %w[hidden clip], metrics["htmlOverflow"]
    assert_includes %w[hidden clip], metrics["bodyOverflow"]
    assert_equal "auto", metrics["trailOverflowY"]
    assert_operator metrics["pathH"], :>, metrics["trailClientH"],
                    "dense path should exceed the trail viewport: #{metrics.inspect}"
    assert_operator metrics["trailScrollH"], :>, metrics["trailClientH"] + 8,
                    "dense trail must scroll: #{metrics.inspect}"

    page.execute_script(<<~JS)
      const trail = document.querySelector('.lp-rpg__stage-trail');
      if (trail) trail.scrollTop = trail.scrollHeight;
    JS
    assert_selector ".lp-climb-path__new-btn", visible: :all, wait: 5
  end

  private

  def lock_phone_viewport!(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
    # Headless Chrome often reports a shorter innerHeight than resize_to; lock metrics.
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: width,
      height: height,
      deviceScaleFactor: 1,
      mobile: true
    )
  end

  def measure_mountain_layout!
    page.evaluate_script(<<~JS)
      (() => {
        const root = document.querySelector('.lp-rpg.is-focus-phase');
        const stage = document.querySelector('.lp-rpg__stage.is-planning');
        const planning = document.querySelector('.lp-rpg__planning');
        const trail = document.querySelector('.lp-rpg__stage-trail');
        const path = document.querySelector('.lp-climb-path');
        const last = document.querySelector('.lp-climb-path__new-btn');
        const nav = document.querySelector('.lp-dash-nav');
        const quests = document.querySelector('.lp-climb-path__quests[open]');
        if (!root || !stage || !planning || !trail || !path || !last || !nav) return null;
        const rs = getComputedStyle(root);
        const ss = getComputedStyle(stage);
        const ps = getComputedStyle(planning);
        const ts = getComputedStyle(trail);
        const stageRect = stage.getBoundingClientRect();
        const planningRect = planning.getBoundingClientRect();
        const trailRect = trail.getBoundingClientRect();
        const pathRect = path.getBoundingClientRect();
        const lastRect = last.getBoundingClientRect();
        const navRect = nav.getBoundingClientRect();
        return {
          vw: window.innerWidth,
          vh: window.innerHeight,
          rootHeight: Math.round(root.getBoundingClientRect().height),
          rootOverflow: rs.overflowY || rs.overflow,
          htmlOverflow: getComputedStyle(document.documentElement).overflowY ||
            getComputedStyle(document.documentElement).overflow,
          bodyOverflow: getComputedStyle(document.body).overflowY ||
            getComputedStyle(document.body).overflow,
          stageAlignSelf: ss.alignSelf,
          stageHeight: ss.height,
          stageMaxHeight: ss.maxHeight,
          planningHeight: ps.height,
          planningMaxHeight: ps.maxHeight,
          trailOverflowY: ts.overflowY,
          trailHeight: ts.height,
          trailMaxHeight: ts.maxHeight,
          stageH: Math.round(stageRect.height),
          planningH: Math.round(planningRect.height),
          trailH: Math.round(trailRect.height),
          pathH: Math.round(pathRect.height),
          trailScrollH: trail.scrollHeight,
          trailClientH: trail.clientHeight,
          lastBottom: Math.round(lastRect.bottom),
          stageBottom: Math.round(stageRect.bottom),
          trailBottom: Math.round(trailRect.bottom),
          navTop: Math.round(navRect.top),
          emptyBelowInTrail: Math.round(trailRect.bottom - lastRect.bottom),
          emptyBelowInStage: Math.round(stageRect.bottom - lastRect.bottom),
          gapToNav: Math.round(navRect.top - lastRect.bottom),
          questsOpen: !!quests
        };
      })()
    JS
  end
end
