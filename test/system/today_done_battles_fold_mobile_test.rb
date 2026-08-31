# frozen_string_literal: true

require "application_system_test_case"

# Today V2 — won battles leave the open list (no done fold).
class TodayDoneBattlesFoldMobileTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    seed_climb!(@user, today_mission: "Fold mission")
    dismiss_onboarding_missions!(@user)
    @user.habits.destroy_all
    @todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Fold mission")
    @todo.update!(start_time: "09:00", end_time: "10:00", completed_at: Time.current)
    @todo.strategy_goal&.update!(completed_at: Time.current)
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

  test "completed battles absent from V2 rows at 375 and 320" do
    page.driver.browser.manage.window.resize_to(375, 700)
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    visit dashboard_path

    assert_today_v2_all_clear_shell!
    assert_selector ".lp-dash-nav.is-today-v2", visible: true, wait: 5
    assert_no_legacy_today_shell!
    assert_no_selector ".lp-today-v2-row"
    assert_battle_row_absent!(title: @todo.title)
    5.times do |i|
      assert_battle_row_absent!(title: "Win #{i + 1}")
    end
    assert_selector "#today-end-of-day", wait: 5
    assert_selector ".lp-today-v2-inline-ack", text: /All battles won today/, visible: :all, wait: 5
    assert_selector ".lp-today-v2-eod-win__stats",
                    text: /You won 5 of 5 battles/,
                    visible: :all,
                    wait: 5

    takeover_h = page.evaluate_script(<<~JS)
      document.querySelector('#today-end-of-day')?.getBoundingClientRect().height
    JS
    puts "MEASURED_V2_EOD_HEIGHT_375=#{takeover_h.round}"
    assert_operator takeover_h.to_f, :>, 200, "win takeover should fill the screen on mobile"

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/today-v2-all-done-375.png")

    page.driver.browser.manage.window.resize_to(320, 700)
    visit dashboard_path
    assert_today_v2_all_clear_shell!
    assert_no_selector ".lp-today-v2-row"
    assert_selector "#today-end-of-day"
    assert_selector ".lp-today-v2-inline-ack", text: /All battles won today/, visible: :all
    narrow_h = page.evaluate_script("document.querySelector('#today-end-of-day')?.getBoundingClientRect().height")
    assert_operator narrow_h.to_f, :>, 200
    page.save_screenshot("/opt/cursor/artifacts/screenshots/today-v2-all-done-320.png")
  end
end
