# frozen_string_literal: true

require "application_system_test_case"

# Mountain V4 photo trail: fixed 100dvh shell with an internal photo scroller.
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
    assert_selector "#mountain-trail", wait: 5
    assert_selector "#trail-camp-#{@camp.id}", text: /Duolingo/

    metrics = measure_mountain_layout!
    File.write("/tmp/sparse-climb-after.json", JSON.pretty_generate(metrics))

    assert_equal PHONE_W, metrics["vw"], "viewport width must match resize_to: #{metrics.inspect}"
    assert_equal PHONE_H, metrics["vh"], "viewport height must match resize_to: #{metrics.inspect}"
    assert_includes %w[hidden clip], metrics["rootOverflow"]
    assert_includes %w[hidden clip], metrics["htmlOverflow"]
    assert_includes %w[hidden clip], metrics["bodyOverflow"]
    assert_in_delta metrics["vh"], metrics["rootHeight"], 2.0
    assert_equal "auto", metrics["photoOverflowY"]
    assert metrics["trailPresent"]
    assert_operator metrics["photoScrollH"], :>, metrics["photoClientH"],
                    "photo trail should scroll internally: #{metrics.inspect}"
    assert_operator metrics["gapTrailToNav"], :<=, 40,
                    "trail bottom should sit near nav: #{metrics.inspect}"
  end

  test "dense climb path still scrolls inside the fixed 100dvh shell" do
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
    assert_selector "#trail-camp-#{@camp.id}", text: /Duolingo/, wait: 5
    assert_selector ".lp-trail-camp", minimum: 10, wait: 5

    metrics = measure_mountain_layout!
    File.write("/tmp/dense-climb-after.json", JSON.pretty_generate(metrics))

    assert_equal PHONE_W, metrics["vw"]
    assert_equal PHONE_H, metrics["vh"]
    assert_includes %w[hidden clip], metrics["rootOverflow"]
    assert_includes %w[hidden clip], metrics["htmlOverflow"]
    assert_includes %w[hidden clip], metrics["bodyOverflow"]
    assert_equal "auto", metrics["photoOverflowY"]
    assert_operator metrics["photoScrollH"], :>, metrics["photoClientH"] + 8,
                    "dense photo trail must scroll: #{metrics.inspect}"
    assert_operator metrics["campCount"], :>=, 10

    page.execute_script(<<~JS)
      const scroll = document.querySelector('.lp-trail__scroll');
      if (scroll) scroll.scrollTop = scroll.scrollHeight;
    JS
    assert_selector ".lp-trail-camp", minimum: 10, visible: :all, wait: 5
  end

  private

  def lock_phone_viewport!(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
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
        const trailShell = document.querySelector('.lp-rpg__stage-trail');
        const mountain = document.querySelector('#mountain-trail');
        const photo = document.querySelector('.lp-trail__scroll');
        const nav = document.querySelector('.lp-dash-nav');
        if (!root || !stage || !trailShell || !mountain || !photo || !nav) return null;
        const rs = getComputedStyle(root);
        const ps = getComputedStyle(photo);
        const stageRect = stage.getBoundingClientRect();
        const trailRect = trailShell.getBoundingClientRect();
        const photoRect = photo.getBoundingClientRect();
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
          photoOverflowY: ps.overflowY,
          stageH: Math.round(stageRect.height),
          trailH: Math.round(trailRect.height),
          photoH: Math.round(photoRect.height),
          photoScrollH: photo.scrollHeight,
          photoClientH: photo.clientHeight,
          stageBottom: Math.round(stageRect.bottom),
          trailBottom: Math.round(trailRect.bottom),
          navTop: Math.round(navRect.top),
          gapTrailToNav: Math.round(navRect.top - trailRect.bottom),
          trailPresent: true,
          campCount: document.querySelectorAll('.lp-trail-camp').length
        };
      })()
    JS
  end
end
