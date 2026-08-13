# frozen_string_literal: true

require "application_system_test_case"

# Done-battles fold density at phone widths.
class TodayDoneBattlesFoldMobileTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    seed_climb!(@user, today_mission: "Fold mission")
    @user.habits.destroy_all
    @user.daily_todos.for_day(Date.current).delete_all

    5.times do |i|
      @user.daily_todos.create!(
        title: "Win #{i + 1}",
        scheduled_on: Date.current,
        aspect_key: "career",
        start_time: format("%02d:00", 9 + i),
        end_time: format("%02d:30", 9 + i),
        completed_at: Time.current,
        position: i
      )
    end
  end

  test "five completed battles collapse and measure shorter at 375 and 320" do
    page.driver.browser.manage.window.resize_to(375, 700)
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"

    assert_selector ".lp-dash-done-fold[open]", wait: 5
    assert_selector ".lp-dash-done-fold .lp-dash-tcard.is-done", count: 5
    assert_selector ".lp-dash-done-fold__count", text: "5"
    assert_no_selector ".lp-dash-timeline__rail .lp-dash-tcard.is-done"

    expanded_h = page.evaluate_script(<<~JS)
      document.querySelector('.lp-dash-done-fold').getBoundingClientRect().height
    JS
    find(".lp-dash-done-fold__summary").click
    assert_selector ".lp-dash-done-fold:not([open])", wait: 2
    collapsed_h = page.evaluate_script(<<~JS)
      document.querySelector('.lp-dash-done-fold').getBoundingClientRect().height
    JS
    puts "MEASURED_DONE_FOLD_EXPANDED_375=#{expanded_h.round}"
    puts "MEASURED_DONE_FOLD_COLLAPSED_375=#{collapsed_h.round}"
    assert_operator collapsed_h, :<, expanded_h * 0.45
    assert_operator collapsed_h, :<, 80

    # Baseline estimate for five full done rows (~110px each) before the fold.
    estimated_before = 5 * 110
    puts "MEASURED_DONE_BATTLES_PAGE_ESTIMATE_BEFORE=#{estimated_before}"
    puts "MEASURED_DONE_BATTLES_COLLAPSED_AFTER_375=#{collapsed_h.round}"

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/today-done-fold-collapsed-375.png")

    page.driver.browser.manage.window.resize_to(320, 700)
    visit dashboard_path
    assert_selector ".lp-dash-done-fold", wait: 5
    # Reset each visit — all done ⇒ open by default
    assert_selector ".lp-dash-done-fold[open]"
    find(".lp-dash-done-fold__summary").click
    assert_selector ".lp-dash-done-fold:not([open])"
    narrow_h = page.evaluate_script("document.querySelector('.lp-dash-done-fold').getBoundingClientRect().height")
    assert_operator narrow_h, :<, 80
    page.save_screenshot("/opt/cursor/artifacts/screenshots/today-done-fold-collapsed-320.png")
  end
end
