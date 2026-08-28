# frozen_string_literal: true

require "application_system_test_case"

class OnboardingMountainTourAnchoringTest < ApplicationSystemTestCase
  VIEWPORTS = [
    [ 360, 800 ],
    [ 412, 800 ],
    [ 768, 1024 ],
    [ 1280, 900 ]
  ].freeze

  setup do
    @user = User.create!(
      name: "Tour",
      email_address: "tour-anchor-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )
  end

  test "tour step 1 anchors spotlight to goal flag across viewports" do
    journey = bootstrap_and_visit!

    assert_selector "[data-controller='onboarding-mountain-tour']", wait: 5
    assert_selector "#onboarding-tour-goal", wait: 5

    VIEWPORTS.each do |width, height|
      page.driver.browser.manage.window.resize_to(width, height)
      page.execute_script("window.dispatchEvent(new Event('resize'))")
      sleep 0.25

      metrics = tour_metrics_for("#onboarding-tour-goal")

      assert metrics["ok"],
             "expected tour spotlight on goal flag at #{width}x#{height}, got #{metrics.inspect}"
      assert metrics["bubbleClear"],
             "expected bubble clear of flag at #{width}x#{height}, got #{metrics.inspect}"
    end
  end

  test "tour step 2 anchors camp above nav with bubble clear at 412px" do
    journey = bootstrap_and_visit!
    page.driver.browser.manage.window.resize_to(412, 800)
    click_button class: "lp-onboarding-tour__next"
    assert_selector "#onboarding-tour-camp", wait: 5
    sleep 0.25

    metrics = tour_metrics_for("#onboarding-tour-camp")
    assert metrics["ok"], "expected spotlight on camp at 412x800, got #{metrics.inspect}"
    assert metrics["bubbleClear"], "expected bubble clear of camp at 412x800, got #{metrics.inspect}"
    assert metrics["aboveNav"], "expected camp above bottom nav at 412x800, got #{metrics.inspect}"
  end

  test "ghosts hidden on steps 2-3 and visible on step 4" do
    bootstrap_and_visit!
    page.driver.browser.manage.window.resize_to(412, 800)

    assert_selector ".lp-trail__ghosts.is-onboarding-tour-hidden", wait: 5

    click_button class: "lp-onboarding-tour__next"
    assert_selector "#onboarding-tour-camp", wait: 5
    assert_selector ".lp-trail__ghosts.is-onboarding-tour-hidden"

    click_button class: "lp-onboarding-tour__next"
    assert_selector "#onboarding-tour-camp", wait: 5
    assert_selector ".lp-trail__ghosts.is-onboarding-tour-hidden"

    click_button class: "lp-onboarding-tour__next"
    assert_selector "#onboarding-tour-add-camp", wait: 5
    assert_no_selector ".lp-trail__ghosts.is-onboarding-tour-hidden"
    assert_selector ".lp-trail-ghost", visible: :all
  end

  test "tour step 4 anchors spotlight to add-camp ghost at 412px" do
    bootstrap_and_visit!
    page.driver.browser.manage.window.resize_to(412, 800)

    3.times { click_button class: "lp-onboarding-tour__next" }
    assert_selector "#onboarding-tour-add-camp", wait: 5
    sleep 0.25

    metrics = tour_metrics_for("#onboarding-tour-add-camp")
    assert metrics["ok"], "expected spotlight on add-camp ghost at 412x800, got #{metrics.inspect}"
    assert metrics["bubbleClear"], "expected bubble clear of ghost at 412x800, got #{metrics.inspect}"
  end

  test "mountain plant fab uses camp wording not project" do
    Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Ship LifePoints",
      camp_title: "Launch",
      battle_titles: [ "Write one test" ]
    )
    journey = @user.reload.primary_focused_journey
    @user.update!(character: "fox")

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    visit life_journey_path(journey)

    assert_selector ".lp-dash-nav__fab[aria-label='Plant a camp']", visible: :all, wait: 5
    assert_no_selector ".lp-dash-nav__fab[aria-label='Plant a project']", visible: :all
  end

  private

  def bootstrap_and_visit!
    Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Become a Ruby Developer",
      camp_title: "Get certified",
      battle_titles: [ "Study chapter 1" ]
    )
    journey = @user.reload.primary_focused_journey
    @user.update!(character: "fox")

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    visit life_journey_path(journey)
    journey
  end

  def tour_metrics_for(target_selector)
    page.evaluate_script(<<~JS)
      (() => {
        const target = document.querySelector(#{target_selector.to_json});
        const spotlight = document.querySelector(".lp-onboarding-tour__spotlight");
        const bubble = document.querySelector(".lp-onboarding-tour__bubble.is-visible");
        const nav = document.querySelector(".lp-dash-nav");
        const fab = document.querySelector(".lp-dash-nav__fab");
        if (!target || !spotlight || spotlight.hidden) {
          return { ok: false, reason: "missing-elements", width: window.innerWidth, height: window.innerHeight };
        }
        const tr = target.getBoundingClientRect();
        const sr = spotlight.getBoundingClientRect();
        const overlaps = !(sr.right < tr.left || sr.left > tr.right || sr.bottom < tr.top || sr.top > tr.bottom);
        const tcx = tr.left + tr.width / 2;
        const tcy = tr.top + tr.height / 2;
        const scx = sr.left + sr.width / 2;
        const scy = sr.top + sr.height / 2;
        const centerDist = Math.hypot(scx - tcx, scy - tcy);
        let bubbleClear = true;
        if (bubble) {
          const br = bubble.getBoundingClientRect();
          bubbleClear = br.bottom < tr.top || br.top > tr.bottom;
        }
        const chromeTop = Math.min(
          nav ? nav.getBoundingClientRect().top : window.innerHeight,
          fab ? fab.getBoundingClientRect().top : window.innerHeight
        );
        const aboveNav = tr.bottom <= chromeTop + 2;
        return {
          ok: overlaps && tr.width > 0 && tr.height > 0 && centerDist < Math.max(tr.width, tr.height),
          overlaps,
          centerDist,
          bubbleClear,
          aboveNav,
          width: window.innerWidth,
          height: window.innerHeight
        };
      })()
    JS
  end
end
