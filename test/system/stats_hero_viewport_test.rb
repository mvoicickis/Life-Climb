# frozen_string_literal: true

require "application_system_test_case"

class StatsHeroViewportTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    seed_climb!(@user, today_mission: "Stats hero viewport")
    dismiss_onboarding_missions!(@user)
  end

  test "stats hero fits at 375 and 320 without horizontal overflow" do
    page.driver.browser.manage.window.resize_to(375, 700)
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"

    visit life_points_path
    assert_selector ".stats-hero", wait: 5
    assert_selector ".stats-hero__lead"
    assert_selector ".stats-hero__meta", text: /Planning power/i
    assert_selector ".stats-hero__link", text: /Mountain/i

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const hero = document.querySelector('.stats-hero');
        const row = document.querySelector('.stats-hero__row');
        const link = document.querySelector('.stats-hero__link');
        const meta = document.querySelector('.stats-hero__meta');
        const linkRange = document.createRange();
        linkRange.selectNodeContents(link);
        const linkTextRect = linkRange.getBoundingClientRect();
        const metaRange = document.createRange();
        metaRange.selectNodeContents(meta);
        const metaTextRect = metaRange.getBoundingClientRect();
        return {
          vw: window.innerWidth,
          scrollWidth: document.documentElement.scrollWidth,
          linkTextRight: linkTextRect.right,
          metaTextRight: metaTextRect.right,
          rowWraps: row.getBoundingClientRect().height > 40
        };
      })()
    JS

    assert_operator metrics["scrollWidth"], :<=, metrics["vw"] + 1,
                    "page should not scroll horizontally (scrollWidth #{metrics['scrollWidth']} vs #{metrics['vw']})"
    assert_operator metrics["linkTextRight"], :<=, metrics["vw"] + 1,
                    "Mountain link text should not overflow viewport"
    assert_operator metrics["metaTextRight"], :<=, metrics["vw"] + 1,
                    "Planning power should not overflow viewport"
    assert metrics["rowWraps"], "stats hero row should stack on narrow width"

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/stats-hero-375.png")

    page.driver.browser.manage.window.resize_to(320, 700)
    visit life_points_path
    assert_selector ".stats-hero", wait: 5

    narrow = page.evaluate_script(<<~JS)
      (() => {
        const link = document.querySelector('.stats-hero__link');
        const meta = document.querySelector('.stats-hero__meta');
        const linkRange = document.createRange();
        linkRange.selectNodeContents(link);
        const linkTextRect = linkRange.getBoundingClientRect();
        const metaRange = document.createRange();
        metaRange.selectNodeContents(meta);
        const metaTextRect = metaRange.getBoundingClientRect();
        return {
          vw: window.innerWidth,
          scrollWidth: document.documentElement.scrollWidth,
          linkTextRight: linkTextRect.right,
          metaTextRight: metaTextRect.right
        };
      })()
    JS

    assert_operator narrow["scrollWidth"], :<=, narrow["vw"] + 1,
                    "page should not scroll horizontally at 320px"
    assert_operator narrow["linkTextRight"], :<=, narrow["vw"] + 1,
                    "Mountain link text should not overflow at 320px"
    assert_operator narrow["metaTextRight"], :<=, narrow["vw"] + 1,
                    "Planning power should not overflow at 320px"
    page.save_screenshot("/opt/cursor/artifacts/screenshots/stats-hero-320.png")
  end
end
