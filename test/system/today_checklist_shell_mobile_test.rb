# frozen_string_literal: true

require "application_system_test_case"

class TodayChecklistShellMobileTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(390, 844)

    seed_climb!(@user, today_mission: "Write tests")
    @area = @user.primary_focused_journey.life_area
    @journey = @user.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.find(&:plan?)
    @section = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "MVP", position: @plan.children.maximum(:position).to_i + 1
    )
    @folder = @section.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Volume 0", position: 0
    )
    @host = Strategy::EnsureFolderQuest.call(folder: @folder)
    @first = @host.practice_tasks.create!(user: @user, title: "Do a lesson", position: 0)
    @second = @host.practice_tasks.create!(user: @user, title: "Review notes", position: 1)
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
  end

  test "mobile checklist expands and last objective finishes the day" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-timeline", wait: 5

    assert_selector ".lp-dash-tcard.is-quest .lp-dash-tcard__title", text: "Volume 0"
    assert_selector ".lp-dash-tcard.is-quest .lp-dash-tcard__win.is-locked"
    assert_selector ".lp-dash-quest-next__step", text: "Do a lesson"
    assert_selector ".lp-dash-quest-next__progress", text: /0 \/ 2/

    find(".lp-dash-quest-next__open").click
    assert_selector "dialog.lp-dash-quest-sheet[open] .lp-dash-checklist__obj-name", text: "Do a lesson"
    assert_selector "dialog.lp-dash-quest-sheet[open] .lp-dash-checklist__obj-name", text: "Review notes"

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/today-checklist-shell-mobile.png")

    within("dialog.lp-dash-quest-sheet[open]") do
      find("button.lp-dash-check[aria-label='Complete Do a lesson']").click
    end
    assert_selector "dialog.lp-dash-quest-sheet[open] .lp-dash-checklist__obj.is-done",
                    text: /Do a lesson/, wait: 5
    assert_selector ".lp-dash-quest-next__step", text: "Review notes", wait: 5
    assert_not @host.reload.completed?

    within("dialog.lp-dash-quest-sheet[open]") do
      find("button.lp-dash-check[aria-label='Complete Review notes']").click
    end
    # Last step finishes the battle — full redirect for celebrate.
    assert_selector ".lp-dash-done-fold, .lp-dash-tcard.is-quest.is-done", wait: 10
    visit dashboard_path unless page.has_css?(".lp-dash-done-fold", wait: 0)
    assert_selector ".lp-dash-done-fold", wait: 5
    find(".lp-dash-done-fold__summary").click unless page.has_css?(".lp-dash-done-fold[open]", wait: 0)
    assert_selector ".lp-dash-done-fold .lp-dash-tcard.is-quest.is-done .lp-dash-tcard__title", text: /Volume 0/i, wait: 5
    assert @first.reload.completed?
    assert @second.reload.completed?
    assert @host.reload.completed?
    todo = @user.daily_todos.for_day(Date.current).find_by!(strategy_goal_id: @host.id)
    assert todo.completed?

    page.save_screenshot("/opt/cursor/artifacts/screenshots/today-checklist-complete-mobile.png")
  end
end
