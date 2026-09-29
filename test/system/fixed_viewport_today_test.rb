# frozen_string_literal: true

require "application_system_test_case"

class FixedViewportTodaySystemTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(390, 844)
    @journey = seed_climb!(@user, today_mission: "Ship viewport")
    dismiss_onboarding_missions!(@user)
  end

  test "photo today locks document scroll and scrolls inside scroll pad" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_today_v2_shell!

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const pad = document.querySelector(".lp-today-scroll__pad");
        const htmlStyle = getComputedStyle(document.documentElement);
        const bodyStyle = getComputedStyle(document.body);
        const padStyle = pad ? getComputedStyle(pad) : null;
        return {
          hasPad: !!pad,
          htmlOverflow: htmlStyle.overflowY || htmlStyle.overflow,
          bodyOverflow: bodyStyle.overflowY || bodyStyle.overflow,
          padOverflowY: padStyle?.overflowY || "",
          docScrollable: document.documentElement.scrollHeight > window.innerHeight + 2
        };
      })()
    JS

    assert metrics["hasPad"], "expected .lp-today-scroll__pad on photo Today"
    assert_includes %w[hidden clip], metrics["htmlOverflow"]
    assert_includes %w[hidden clip], metrics["bodyOverflow"]
    assert_equal "auto", metrics["padOverflowY"]
    assert_equal false, metrics["docScrollable"],
                 "document should not be the scroll owner on photo Today: #{metrics.inspect}"

    page.driver.browser.manage.window.resize_to(360, 640)

    layout = page.evaluate_script(<<~JS)
      (() => {
        const pad = document.querySelector(".lp-today-scroll__pad");
        const bg = document.querySelector(".lp-today-photo-bg");
        if (!pad || !bg) return { ok: false };
        const padTop = pad.getBoundingClientRect().top;
        pad.scrollTop = Math.min(320, pad.scrollHeight);
        const bgTopAfterScroll = bg.getBoundingClientRect().top;
        return { ok: true, padTop, bgTopAfterScroll };
      })()
    JS

    assert layout["ok"], "expected photo Today pad and background"
    assert_operator layout["padTop"].to_f, :<, 40,
                    "scroll pad should start near viewport top at 360×640 (got #{layout['padTop']})"
    assert_operator layout["bgTopAfterScroll"].to_f, :<, 1,
                    "photo bg should stay pinned to shell top after pad scroll (got #{layout['bgTopAfterScroll']})"
  end
end
