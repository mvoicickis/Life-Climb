# frozen_string_literal: true

require "application_system_test_case"

class HabitDestroyTurboCacheMobileTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(390, 844)
    seed_climb!(@user, today_mission: "Ship auth")
    @user.habits.destroy_all
    @habit = @user.habits.create!(
      name: "Temp stretch", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth"
    )
    @user.habits.create!(
      name: "Keep me", unit: "pages", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", goal: 10
    )
  end

  test "delete habit then navigate to Today without hard refresh hides it" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-anytime", wait: 5
    assert_selector ".lp-dash-anytime .lp-dash-tcard__title", text: "Temp stretch"

    visit habits_path
    assert_selector ".lp-habits", wait: 5
    card = find(".lp-habits__card", text: "Temp stretch")
    accept_confirm do
      card.click_button "Delete"
    end
    assert_selector ".lp-habits", wait: 5
    assert_no_selector ".lp-habits__name", text: "Temp stretch"
    assert_selector "[data-controller='turbo-cache'][data-turbo-cache-clear-value='true']", visible: :all

    within(".lp-dash-nav") { click_link "Today" }
    assert_selector ".lp-dash-anytime", wait: 5
    assert_no_selector ".lp-dash-anytime .lp-dash-tcard__title", text: "Temp stretch"
    assert_selector ".lp-dash-anytime .lp-dash-tcard__title", text: "Keep me"

    page.save_screenshot("/opt/cursor/artifacts/screenshots/habit-destroy-today-fresh-nav.png")
  end
end
