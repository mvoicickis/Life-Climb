# frozen_string_literal: true

require "application_system_test_case"

# Regression: #311 habit ⋯ sheet was clipped by overflow:hidden on the slot card,
# rendering as an empty grey box that covered the title/progress.
class HabitOverflowMenuMobileTest < ApplicationSystemTestCase
  setup { enable_habits! }
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
      assert_selector "#today_habit_#{@habit.id} .lp-dash-habit__sheet", text: /Quick add button/i
      assert_selector "#today_habit_#{@habit.id} .lp-dash-habit__chip", count: 4
      assert_no_selector "#today_habit_#{@habit.id} .lp-dash-habit__sheet", text: /Uses \+/

      assert title.visible?, "habit title must stay visible while menu is open @#{width}"
      assert segs.visible?, "progress segs must stay visible while menu is open @#{width}"

      contrast = page.evaluate_script(<<~JS)
        (() => {
          const title = document.querySelector("#today_habit_#{@habit.id} .lp-dash-tcard__title");
          const label = document.querySelector("#today_habit_#{@habit.id} .lp-dash-habit__sheet-label");
          const parse = (c) => {
            const m = String(c).match(/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)/);
            if (!m) return null;
            const [r, g, b] = m.slice(1).map(Number);
            return (0.2126*r + 0.7152*g + 0.0722*b) / 255;
          };
          return {
            title: parse(getComputedStyle(title).color),
            label: parse(getComputedStyle(label).color)
          };
        })()
      JS
      assert_operator contrast["title"], :>=, 0.55, "habit title must stay light-on-dark @#{width}"
      assert_operator contrast["label"], :>=, 0.35, "sheet labels must stay readable on dark sheet @#{width}"

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

      # Regression after #314: sheet was right-anchored to the ⋯ and ran past the
      # left viewport edge. Assert the open sheet stays fully on screen.
      bounds = page.evaluate_script(<<~JS)
        (() => {
          const sheet = document.querySelector("#today_habit_#{@habit.id} .lp-dash-habit__sheet");
          const r = sheet.getBoundingClientRect();
          return {
            left: r.left,
            right: r.right,
            width: r.width,
            vw: window.innerWidth
          };
        })()
      JS
      assert_operator bounds["left"], :>=, -0.5, "sheet left must stay in viewport @#{width} (got #{bounds['left']})"
      assert_operator bounds["right"], :<=, bounds["vw"] + 0.5,
                      "sheet right must stay in viewport @#{width} (right=#{bounds['right']} vw=#{bounds['vw']})"
      assert_operator bounds["width"], :>, 120, "sheet should have usable width @#{width}"

      if width == 375
        find("#today_habit_#{@habit.id} .lp-dash-habit__chip", text: "+10").click
        assert_selector "#today_habit_#{@habit.id} details.lp-dash-habit__menu[open]", wait: 3
        assert_selector "#today_quick_habit_#{@habit.id} button[aria-label='Add 10 reps']", wait: 3
        assert_selector "#today_habit_#{@habit.id} .lp-dash-habit__chip.is-on", text: "+10"
      end

      page.save_screenshot("/opt/cursor/artifacts/screenshots/habit-menu-open-#{width}.png")

      # Second tap on ⋯ closes (native details + tcard-menu).
      dots.click
      assert_no_selector "#today_habit_#{@habit.id} details.lp-dash-habit__menu[open]"

      dots.click
      assert_selector "#today_habit_#{@habit.id} details.lp-dash-habit__menu[open]"
      page.execute_script(<<~JS)
        document.querySelector("#today_habit_#{@habit.id} .lp-dash-habit__scrim").click()
      JS
      assert_no_selector "#today_habit_#{@habit.id} details.lp-dash-habit__menu[open]"

      dots.click
      assert_selector "#today_habit_#{@habit.id} details.lp-dash-habit__menu[open]"
      page.send_keys(:escape)
      assert_no_selector "#today_habit_#{@habit.id} details.lp-dash-habit__menu[open]"
    end
  end
end
