# frozen_string_literal: true

require "application_system_test_case"

class OnboardingMountainTourAnchoringTest < ApplicationSystemTestCase
  VIEWPORTS = [
    [ 360, 800 ],
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
    assert_selector "[data-controller='onboarding-mountain-tour']", wait: 5
    assert_selector "#onboarding-tour-goal", wait: 5

    VIEWPORTS.each do |width, height|
      page.driver.browser.manage.window.resize_to(width, height)
      page.execute_script(<<~JS)
        (() => {
          const flag = document.getElementById("onboarding-tour-goal");
          flag?.scrollIntoView({ block: "center", inline: "center" });
          window.dispatchEvent(new Event("resize"));
        })()
      JS
      sleep 0.25

      metrics = page.evaluate_script(<<~JS)
        (() => {
          const flag = document.getElementById("onboarding-tour-goal");
          const spotlight = document.querySelector(".lp-onboarding-tour__spotlight");
          const bubble = document.querySelector(".lp-onboarding-tour__bubble.is-visible");
          if (!flag || !spotlight || spotlight.hidden) {
            return { ok: false, reason: "missing-elements", width: window.innerWidth, height: window.innerHeight };
          }
          const fr = flag.getBoundingClientRect();
          const sr = spotlight.getBoundingClientRect();
          const overlaps = !(sr.right < fr.left || sr.left > fr.right || sr.bottom < fr.top || sr.top > fr.bottom);
          const flagCx = fr.left + fr.width / 2;
          const flagCy = fr.top + fr.height / 2;
          const spotCx = sr.left + sr.width / 2;
          const spotCy = sr.top + sr.height / 2;
          const centerDist = Math.hypot(spotCx - flagCx, spotCy - flagCy);
          let bubbleNear = true;
          if (bubble) {
            const br = bubble.getBoundingClientRect();
            bubbleNear = br.bottom < fr.top || br.top > fr.bottom;
          }
          return {
            ok: overlaps && fr.width > 0 && fr.height > 0 && centerDist < Math.max(fr.width, fr.height),
            overlaps,
            centerDist,
            bubbleNear,
            width: window.innerWidth,
            height: window.innerHeight
          };
        })()
      JS

      assert metrics["ok"],
             "expected tour spotlight on goal flag at #{width}x#{height}, got #{metrics.inspect}"
      assert metrics["bubbleNear"],
             "expected bubble clear of flag at #{width}x#{height}, got #{metrics.inspect}"
    end
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
end
