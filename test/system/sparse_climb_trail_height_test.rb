# frozen_string_literal: true

require "application_system_test_case"

# Mountain V4 photo trail: fixed 100dvh shell with an internal photo scroller.
class SparseClimbTrailHeightTest < ApplicationSystemTestCase
  PHONE_W = 390
  PHONE_H = 844
  NARROW_W = 360
  NARROW_H = 640

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

  test "sparse climb fits the mountain in the viewport with peak visible" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp.id)
    assert_selector "#mountain-trail", wait: 5
    assert_selector "#mountain-trail.is-sparse-trail", wait: 5
    assert_selector "#trail-camp-#{@camp.id}[aria-label='Duolingo']", visible: :all

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
    assert metrics["sparseTrail"]
    assert_operator metrics["surfaceH"], :<=, metrics["photoClientH"] + 2,
                    "sparse mountain should fit the scroll viewport: #{metrics.inspect}"
    assert_operator metrics["photoScrollH"], :>=, metrics["photoClientH"],
                    "dock may extend scroll range below the photo: #{metrics.inspect}"
    assert metrics["peakInView"], "peak pennant should be visible without scrolling: #{metrics.inspect}"
    assert_operator metrics["gapTrailToNav"], :<=, 40,
                    "trail bottom should sit near nav: #{metrics.inspect}"
  end

  test "sparse two-camp trail keeps upper camp inside sparse band at 360x640" do
    lock_phone_viewport!(NARROW_W, NARROW_H)
    second = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Phrasebook", position: 1,
      trail_x: 0.5, trail_y: MountainTrailHelper::TRAIL_Y_MAX
    )

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp.id)
    assert_selector "#trail-camp-#{second.id}", visible: :all, wait: 5

    metrics = measure_mountain_layout!(narrow: true)
    assert metrics["sparseTrail"]
    assert_operator metrics["upperCampY"], :<=, MountainTrailHelper::TRAIL_Y_SPARSE_MAX + 0.01,
                    "upper camp should use sparse band, not dense foot: #{metrics.inspect}"
    assert metrics["campAboveDock"], "camp caption should stay above dock at scrollTop 0: #{metrics.inspect}"
    assert metrics["peakInView"]
  end

  test "dense climb path still scrolls inside the fixed 100dvh shell" do
    @camp.update!(position: 8)
    8.times do |i|
      @plan.children.create!(
        user: @user, life_area: @area, life_journey: @journey,
        horizon: "project", title: "Open Camp #{i + 1}", position: i
      )
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
    assert_selector "#trail-camp-#{@camp.id}[aria-label='Duolingo']", visible: :all, wait: 5
    assert_no_selector "#mountain-trail.is-sparse-trail"
    assert_selector ".lp-trail-camp", minimum: 10, visible: :all, wait: 5

    metrics = measure_mountain_layout!
    File.write("/tmp/dense-climb-after.json", JSON.pretty_generate(metrics))

    assert_equal PHONE_W, metrics["vw"]
    assert_equal PHONE_H, metrics["vh"]
    assert_includes %w[hidden clip], metrics["rootOverflow"]
    assert_includes %w[hidden clip], metrics["htmlOverflow"]
    assert_includes %w[hidden clip], metrics["bodyOverflow"]
    assert_equal "auto", metrics["photoOverflowY"]
    refute metrics["sparseTrail"]
    assert_operator metrics["surfaceH"], :>, metrics["photoClientH"],
                    "photo surface should exceed the trail viewport: #{metrics.inspect}"
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

  def measure_mountain_layout!(narrow: false)
    page.evaluate_script(<<~JS)
      (() => {
        const root = document.querySelector('.lp-rpg.is-focus-phase');
        const stage = document.querySelector('.lp-rpg__stage.is-planning');
        const trailShell = document.querySelector('.lp-rpg__stage-trail');
        const mountain = document.querySelector('#mountain-trail');
        const photo = document.querySelector('.lp-trail__scroll');
        const surface = document.querySelector('.lp-trail__surface');
        const nav = document.querySelector('.lp-dash-nav');
        if (!root || !stage || !trailShell || !mountain || !photo || !nav) return null;
        const rs = getComputedStyle(root);
        const ps = getComputedStyle(photo);
        const stageRect = stage.getBoundingClientRect();
        const trailRect = trailShell.getBoundingClientRect();
        const photoRect = photo.getBoundingClientRect();
        const surfaceRect = surface?.getBoundingClientRect();
        const navRect = nav.getBoundingClientRect();
        const peak = document.querySelector('.lp-trail__peak');
        const peakRect = peak?.getBoundingClientRect();
        const camps = Array.from(document.querySelectorAll('.lp-trail-camp'));
        const upperCamp = camps.reduce((best, el) => {
          const y = Number.parseFloat(el.dataset.trailY || el.style.getPropertyValue('--lp-trail-y') || '0');
          return !best || y > Number.parseFloat(best.dataset.trailY || '0') ? el : best;
        }, null);
        const upperCampY = upperCamp
          ? Number.parseFloat(upperCamp.dataset.trailY || upperCamp.style.getPropertyValue('--lp-trail-y') || '0')
          : null;
        const dock = document.querySelector('.lp-trail__dock');
        const dockRect = dock?.getBoundingClientRect();
        const campCaption = upperCamp?.querySelector('.lp-trail-camp__caption');
        const captionRect = campCaption?.getBoundingClientRect();
        const peakInView = Boolean(
          peakRect &&
          photoRect &&
          peakRect.bottom > photoRect.top + 4 &&
          peakRect.top < photoRect.bottom - 4
        );
        const campAboveDock = Boolean(
          !dockRect ||
          !captionRect ||
          captionRect.bottom <= dockRect.top + 2
        );
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
          surfaceH: surfaceRect ? Math.round(surfaceRect.height) : 0,
          photoScrollH: photo.scrollHeight,
          photoClientH: photo.clientHeight,
          stageBottom: Math.round(stageRect.bottom),
          trailBottom: Math.round(trailRect.bottom),
          navTop: Math.round(navRect.top),
          gapTrailToNav: Math.round(navRect.top - trailRect.bottom),
          trailPresent: true,
          sparseTrail: mountain.classList.contains('is-sparse-trail'),
          peakInView,
          campAboveDock,
          upperCampY,
          campCount: camps.length
        };
      })()
    JS
  end
end
