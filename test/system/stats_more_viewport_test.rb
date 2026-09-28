# frozen_string_literal: true

require "application_system_test_case"

class StatsMoreViewportTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    seed_climb!(@user, today_mission: "More stats viewport")
    dismiss_onboarding_missions!(@user)
  end

  test "more stats page fits at 360 without horizontal overflow" do
    page.driver.browser.manage.window.resize_to(360, 700)
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_today_v2_shell!

    visit more_life_points_path
    assert_selector ".lp-stats-more__card", wait: 5

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const card = document.querySelector('.lp-stats-more__card');
        const chart = document.querySelector('.lp-stats-more__chart');
        const cardRect = card.getBoundingClientRect();
        const chartRect = chart.getBoundingClientRect();
        return {
          vw: window.innerWidth,
          scrollWidth: document.documentElement.scrollWidth,
          cardRight: cardRect.right,
          chartRight: chartRect.right
        };
      })()
    JS

    assert_operator metrics["scrollWidth"], :<=, metrics["vw"] + 1,
                    "page should not scroll horizontally at 360px"
    assert_operator metrics["cardRight"], :<=, metrics["vw"] + 1,
                    "stat card should not overflow viewport"
    assert_operator metrics["chartRight"], :<=, metrics["vw"] + 1,
                    "chart should not overflow viewport"
  end
end
