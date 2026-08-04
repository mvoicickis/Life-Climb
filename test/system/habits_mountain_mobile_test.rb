# frozen_string_literal: true

require "application_system_test_case"

class HabitsMountainMobileTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(390, 844)

    @journey = seed_climb!(@user, today_mission: "Ship auth")
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.find(&:plan?)
    @section = @plan.children.find(&:project?)

    @user.habits.destroy_all
    @user.habits.create!(
      name: "Meditate", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", life_journey: @journey
    )
    @user.habits.create!(
      name: "Pages read", unit: "pages", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", goal: 10, life_journey: @journey
    )
    @user.habits.create!(
      name: "Steps", unit: "steps", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", goal: 5000
    )
  end

  test "five item nav and mountain supporting habits look clean on mobile" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    assert_selector ".lp-dash-nav__link", text: /Habits/i
    links = all(".lp-dash-nav__link")
    assert_equal 5, links.size
    widths = links.map { |el| el.native.size.width }
    assert widths.all? { |w| w >= 48 }, "nav links should stay tappable without collapsing"
    assert widths.sum <= 390, "nav row should fit the mobile viewport without overflow"

    page.save_screenshot("/opt/cursor/artifacts/screenshots/habits-nav-five-mobile.png")

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @section.id)
    assert_selector ".lp-rpg-habits", wait: 5
    assert_selector ".lp-rpg-habits__name", text: /Meditate/
    assert_selector ".lp-rpg-habits__name", text: /Pages read/
    assert_selector ".lp-rpg-habits__name", text: /Steps/, count: 0
    page.execute_script("document.querySelector('.lp-rpg-habits')?.scrollIntoView({block: 'center'})")
    sleep 0.3
    page.save_screenshot("/opt/cursor/artifacts/screenshots/mountain-supporting-habits-mobile.png")

    visit habits_path
    assert_selector ".lp-habits", wait: 5
    assert_selector ".lp-dash-nav__link.is-active", text: /Habits/i
    page.save_screenshot("/opt/cursor/artifacts/screenshots/habits-page-mobile.png")
  end
end
