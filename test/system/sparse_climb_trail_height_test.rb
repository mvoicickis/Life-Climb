# frozen_string_literal: true

require "application_system_test_case"

# Sparse journeys must not stretch .lp-rpg__stage-trail to a full-height empty scrollport.
class SparseClimbTrailHeightTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @user.update!(character: "fox", support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    page.driver.browser.manage.window.resize_to(390, 844)

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

  test "sparse climb trail sizes to content inside the fixed 100dvh shell" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp.id)
    assert_selector ".lp-climb-path", wait: 5
    assert_selector ".lp-climb-path__new-btn", wait: 5

    # Collapse quest panels so content is shorter than the planning slot —
    # the bug is the empty scrollport under short content, not open quests.
    page.execute_script(<<~JS)
      document.querySelectorAll('.lp-climb-path__quests[open]').forEach((el) => {
        el.removeAttribute('open');
      });
    JS

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const root = document.querySelector('.lp-rpg.is-focus-phase');
        const stage = document.querySelector('.lp-rpg__stage.is-planning');
        const planning = document.querySelector('.lp-rpg__planning');
        const trail = document.querySelector('.lp-rpg__stage-trail');
        const path = document.querySelector('.lp-climb-path');
        const habits = document.querySelector('.lp-rpg-habits');
        if (!root || !stage || !planning || !trail || !path) return null;
        const rs = getComputedStyle(root);
        const ps = getComputedStyle(planning);
        const ts = getComputedStyle(trail);
        const trailRect = trail.getBoundingClientRect();
        const stageRect = stage.getBoundingClientRect();
        const pathRect = path.getBoundingClientRect();
        return {
          rootHeight: Math.round(root.getBoundingClientRect().height),
          rootOverflow: rs.overflowY || rs.overflow,
          htmlOverflow: getComputedStyle(document.documentElement).overflowY ||
            getComputedStyle(document.documentElement).overflow,
          bodyOverflow: getComputedStyle(document.body).overflowY ||
            getComputedStyle(document.body).overflow,
          planningDisplay: ps.display,
          planningFlexDir: ps.flexDirection,
          trailOverflowY: ts.overflowY,
          trailFlexGrow: ts.flexGrow,
          trailFlexShrink: ts.flexShrink,
          trailMaxHeight: ts.maxHeight,
          trailH: Math.round(trailRect.height),
          pathH: Math.round(pathRect.height),
          stageH: Math.round(stageRect.height),
          trailScrollH: trail.scrollHeight,
          trailClientH: trail.clientHeight,
          habitsPresent: !!habits,
          vw: window.innerWidth,
          vh: window.innerHeight
        };
      })()
    JS

    assert metrics.present?, "Mountain planning trail missing"
    assert_includes %w[hidden clip], metrics["rootOverflow"]
    assert_includes %w[hidden clip], metrics["htmlOverflow"]
    assert_includes %w[hidden clip], metrics["bodyOverflow"]
    # Shell stays fixed to the viewport (PR248) — computed px ≈ innerHeight.
    assert_in_delta metrics["vh"], metrics["rootHeight"], 2.0
    assert_equal "flex", metrics["planningDisplay"]
    assert_equal "column", metrics["planningFlexDir"]
    assert_equal "auto", metrics["trailOverflowY"]
    assert_equal "0", metrics["trailFlexGrow"].to_s
    assert_operator metrics["trailFlexShrink"].to_f, :>=, 1.0
    assert_equal false, metrics["habitsPresent"]

    # Trail hugs climb-path content — not the full planning stage.
    assert_in_delta metrics["pathH"], metrics["trailH"], 24,
                    "sparse trail should size to climb-path content: #{metrics.inspect}"
    assert_operator metrics["trailH"], :<, (metrics["stageH"] * 0.72),
                    "sparse trail must not claim most of the stage: #{metrics.inspect}"
    assert_operator metrics["trailScrollH"], :<=, metrics["trailClientH"] + 2,
                    "sparse trail should not need an empty scrollport: #{metrics.inspect}"
  end
end
