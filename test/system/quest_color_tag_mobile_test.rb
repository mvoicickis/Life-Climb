# frozen_string_literal: true

require "application_system_test_case"

class QuestColorTagMobileTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(390, 844)

    seed_climb!(@user, today_mission: "Write tests")
    @area = @user.primary_focused_journey.life_area
    @journey = @user.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.find(&:plan?)
    @colored = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Purple Volume",
      position: @plan.children.maximum(:position).to_i + 1, color_key: "purple"
    )
    @plain = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Plain Volume",
      position: @plan.children.maximum(:position).to_i + 1
    )
    host = Strategy::EnsureFolderQuest.call(folder: @colored)
    host.practice_tasks.create!(user: @user, title: "Do a lesson", position: 0)
    host.practice_tasks.create!(user: @user, title: "Review notes", position: 1)
    plain_host = Strategy::EnsureFolderQuest.call(folder: @plain)
    plain_host.practice_tasks.create!(user: @user, title: "Open notes", position: 0)
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
  end

  test "mobile colored quest shows on Mountain and Today; plain stays default" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-timeline", wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @colored.id)
    assert_selector ".lp-climb-path__quests[open]", wait: 5
    assert_selector ".lp-climb-path__quest.has-color.is-purple .lp-climb-path__quest-title", text: /Purple Volume/
    assert_selector ".lp-climb-path__node", text: /Plain Volume/
    assert_no_selector ".lp-climb-path__quest.has-color", text: /Plain Volume/
    assert_no_selector "a.lp-qs-card"
    page.save_screenshot("/opt/cursor/artifacts/screenshots/quest-color-mountain-mobile.png")

    visit dashboard_path
    assert_selector ".lp-dash-tcard.is-quest", text: /Purple Volume/, wait: 5
    assert_selector ".lp-dash-tcard.is-quest .lp-dash-quest-next__step", text: /Do a lesson/
    find(".lp-dash-tcard.is-quest .lp-dash-quest-next__open", match: :first).click
    assert_selector "dialog.lp-dash-quest-sheet[open] .lp-dash-checklist__obj-name", text: /Do a lesson/
    assert_selector "dialog.lp-dash-quest-sheet[open] .lp-dash-checklist__obj-name", text: /Review notes/
    assert_selector ".lp-dash-tcard.is-quest", text: /Plain Volume/
    page.save_screenshot("/opt/cursor/artifacts/screenshots/quest-color-today-mobile.png")
  end
end
