# frozen_string_literal: true

require "application_system_test_case"

# Regression: #311 habit ⋯ sheet was clipped by overflow:hidden on the slot card,
# rendering as an empty grey box that covered the title/progress.
class HabitOverflowMenuMobileTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @journey = seed_climb!(@user, today_mission: "Log habits")
    @user.habits.destroy_all
    @habit = @user.habits.create!(
      name: "Push-Ups",
      unit: "reps",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "growth",
      goal: 25,
      quantity_checkin: true,
      life_journey: @journey
    )
  end

  test "habit menu opens with items visible and does not collapse the card at 375 and 320" do
    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector "#today_habit_#{@habit.id}", wait: 5

    [ 375, 320 ].each do |width|
      page.driver.browser.manage.window.resize_to(width, 844)
      visit dashboard_path
      assert_selector "#today_habit_#{@habit.id}", wait: 5

      card = find("#today_habit_#{@habit.id}")
      title = card.find(".lp-dash-tcard__title", text: "Push-Ups")
      segs = card.find(".lp-dash-habit__segs")
      dots = card.find("summary.lp-dash-habit__dots")

      dots.click
      assert_selector "#today_habit_#{@habit.id} details.lp-dash-habit__menu[open]", wait: 2
      assert_selector "#today_habit_#{@habit.id} .lp-dash-habit__sheet", text: /Enter exact amount/
      assert_selector "#today_habit_#{@habit.id} .lp-dash-habit__sheet", text: /Set total/
      assert_selector "#today_habit_#{@habit.id} .lp-dash-habit__sheet", text: /Uses \+5 and \+15/

      assert title.visible?, "habit title must stay visible while menu is open @#{width}"
      assert segs.visible?, "progress segs must stay visible while menu is open @#{width}"

      overflow = page.evaluate_script(<<~JS)
        getComputedStyle(document.getElementById("today_habit_#{@habit.id}")).overflow
      JS
      assert_equal "visible", overflow, "open menu must lift slot overflow clip @#{width}"

      sheet_visible = page.evaluate_script(<<~JS)
        (() => {
          const sheet = document.querySelector("#today_habit_#{@habit.id} .lp-dash-habit__sheet");
          const label = sheet?.querySelector(".lp-dash-habit__sheet-label");
          if (!sheet || !label) return false;
          const r = label.getBoundingClientRect();
          return r.width > 0 && r.height > 0;
        })()
      JS
      assert sheet_visible, "menu labels must have a non-zero box @#{width}"

      tap = page.evaluate_script(<<~JS)
        (() => {
          const btn = document.querySelector("#today_habit_#{@habit.id} .lp-dash-habit__sheet-btn");
          const min = parseFloat(getComputedStyle(document.documentElement).getPropertyValue("--lp-tap")) || 44;
          const r = btn.getBoundingClientRect();
          return { h: r.height, min };
        })()
      JS
      assert_operator tap["h"], :>=, tap["min"] - 1, "sheet buttons must meet --lp-tap @#{width}"

      page.save_screenshot("/opt/cursor/artifacts/screenshots/habit-menu-open-#{width}.png")

      dots.click
      assert_no_selector "#today_habit_#{@habit.id} details.lp-dash-habit__menu[open]"

      dots.click
      assert_selector "#today_habit_#{@habit.id} details.lp-dash-habit__menu[open]"
      page.execute_script("document.elementFromPoint(4, 4).dispatchEvent(new PointerEvent('pointerdown', {bubbles:true}))")
      assert_no_selector "#today_habit_#{@habit.id} details.lp-dash-habit__menu[open]"
    end
  end
end
