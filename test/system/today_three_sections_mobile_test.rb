# frozen_string_literal: true

require "application_system_test_case"

class TodayThreeSectionsMobileTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(390, 844)

    seed_climb!(@user, today_mission: "Ship auth")
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

  test "mobile Today shows timeline cards and Anytime habits" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-timeline", wait: 5

    assert_selector ".lp-dash-tcard__title", text: "Ship auth"
    assert_selector ".lp-dash-tcard__title", text: "Write tests"
    assert_selector ".lp-dash-tcard__title", text: "Review PR"
    assert_selector ".lp-dash-tcard.is-quest .lp-dash-tcard__title", text: /Volume One/
    assert_selector ".lp-dash-tcard.is-quest .lp-dash-tcard__title", text: /Volume Two/
    assert_no_selector ".lp-dash-section.is-battles"
    assert_no_selector ".lp-dash-section.is-quests"
    assert_no_selector ".lp-dash-section.is-habits"

    assert_selector ".lp-dash-anytime", text: /Habits/i
    assert_selector ".lp-dash-anytime .lp-dash-tcard__title", text: /Meditate/
    assert_selector ".lp-dash-anytime .lp-dash-tcard__title", text: /Pages read/
    assert_selector ".lp-dash-anytime .lp-dash-tcard__title", text: /Steps/

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/today-three-sections-mobile.png")
    page.execute_script("document.querySelector('.lp-dash-anytime')?.scrollIntoView({block: 'center'})")
    sleep 0.3
    page.save_screenshot("/opt/cursor/artifacts/screenshots/today-three-sections-habits-mobile.png")
  end
end
