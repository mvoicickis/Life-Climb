# frozen_string_literal: true

require "application_system_test_case"

class TodayThreeSectionsMobileTest < ApplicationSystemTestCase
  setup { enable_habits! }
  include ClimbTestHelper

  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(390, 844)

    seed_climb!(@user, today_mission: "Ship auth")
    dismiss_onboarding_missions!(@user)
    @area = @user.primary_focused_journey.life_area
    @journey = @user.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.find(&:plan?)
    @section = @plan.children.find(&:project?)
    @leaf = @section

    @leaf.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Write tests", scheduled_on: Date.current, position: 1
    )
    @leaf.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Review PR", scheduled_on: Date.current, position: 2
    )

    quest = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Volume One",
      position: @plan.children.maximum(:position).to_i + 1, color_key: "coral"
    )
    host = Strategy::EnsureFolderQuest.call(folder: quest)
    host.practice_tasks.create!(user: @user, title: "Do a lesson", position: 0)
    host.practice_tasks.create!(user: @user, title: "Review notes", position: 1)

    quest2 = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Volume Two",
      position: @plan.children.maximum(:position).to_i + 1
    )
    host2 = Strategy::EnsureFolderQuest.call(folder: quest2)
    host2.practice_tasks.create!(user: @user, title: "Sketch UI", position: 0)

    Strategy::CascadeToDaily.call(user: @user, life_area: @area)

    @user.habits.destroy_all
    @user.habits.create!(
      name: "Meditate", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth"
    )
    @user.habits.create!(
      name: "Pages read", unit: "pages", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", goal: 10
    )
    @user.habits.create!(
      name: "Steps", unit: "steps", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", goal: 5000
    )
  end

  test "mobile Today V2 shows flat battle rows with habits and no legacy sections" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_today_v2_shell!
    assert_no_legacy_today_shell!

    assert_battle_row!(title: "Ship auth", camp: "Auth")
    assert_battle_row!(title: "Write tests", camp: "Auth")
    assert_battle_row!(title: "Review PR", camp: "Auth")
    assert_battle_row!(title: "Volume One", camp: "Volume One")
    assert_battle_row!(title: "Volume Two", camp: "Volume Two")
    assert_no_selector ".lp-dash-section.is-battles"
    assert_no_selector ".lp-dash-section.is-quests"
    assert_no_selector ".lp-dash-section.is-habits"
    assert_no_selector ".lp-dash-quest-next"
    assert_no_selector ".lp-dash-tcard.is-quest"
    assert_selector ".lp-dash-anytime"

    visit habits_path
    assert_selector ".lp-habits", wait: 5
    assert_selector ".lp-habits__name", text: /Meditate/
    assert_selector ".lp-habits__name", text: /Pages read/
    assert_selector ".lp-habits__name", text: /Steps/

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/today-three-sections-mobile.png")
    visit dashboard_path
    page.save_screenshot("/opt/cursor/artifacts/screenshots/today-three-sections-v2-mobile.png")
  end
end
