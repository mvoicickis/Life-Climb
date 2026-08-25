# frozen_string_literal: true

require "application_system_test_case"

class TodayChecklistShellMobileTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(390, 844)

    seed_climb!(@user, today_mission: "Write tests")
    dismiss_onboarding_missions!(@user)
    @area = @user.primary_focused_journey.life_area
    @journey = @user.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.find(&:plan?)
    @section = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Volume 0", position: @plan.children.maximum(:position).to_i + 1
    )
    @folder = @section
    @host = Strategy::EnsureFolderQuest.call(folder: @folder)
    @first = @host.practice_tasks.create!(user: @user, title: "Do a lesson", position: 0)
    @second = @host.practice_tasks.create!(user: @user, title: "Review notes", position: 1)
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    @todo = @user.daily_todos.for_day(Date.current).find_by!(strategy_goal_id: @host.id)
  end

  test "mobile V2 quest row completes objectives off-sheet and disappears when won" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_today_v2_shell!

    assert_battle_row!(title: "Volume 0", camp: "Volume 0", todo: @todo)
    assert_no_selector ".lp-dash-quest-next"
    assert_no_selector "dialog.lp-dash-quest-sheet"
    assert_no_selector ".lp-dash-tcard.is-quest"

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/today-checklist-shell-mobile.png")

    patch_practice_task!(@first)
    visit dashboard_path
    assert_battle_row!(title: "Volume 0", todo: @todo)
    assert @first.reload.completed?
    assert_not @host.reload.completed?

    patch_practice_task!(@second)
    visit dashboard_path
    assert_battle_row_absent!(title: "Volume 0")
    assert_no_selector ".lp-dash-done-fold"
    assert @first.reload.completed?
    assert @second.reload.completed?
    assert @host.reload.completed?
    assert @todo.reload.completed?

    page.save_screenshot("/opt/cursor/artifacts/screenshots/today-checklist-complete-mobile.png")
  end
end
