# frozen_string_literal: true

require "application_system_test_case"

class ObjectiveQuantityOptInMobileTest < ApplicationSystemTestCase
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
      horizon: "project", title: "Read Atomic Habits",
      position: @plan.children.maximum(:position).to_i + 1,
      target_amount: 700, unit: "pages", current_amount: 7
    )
    @folder = @section
    @host = Strategy::EnsureFolderQuest.call(folder: @folder)
    @tracked = @host.practice_tasks.create!(
      user: @user, title: "Read chapter 3", position: 0, track_quantity: true
    )
    @plain = @host.practice_tasks.create!(
      user: @user, title: "Review notes", position: 1, track_quantity: false
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    @todo = @user.daily_todos.for_day(Date.current).find_by!(strategy_goal_id: @host.id)
  end

  test "mobile quest row stays flat; objectives complete off-sheet and vanish when won" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_today_v2_shell!
    assert_battle_row!(title: "Read Atomic Habits", camp: "Read Atomic Habits", todo: @todo)
    assert_no_selector ".lp-dash-quest-next"
    assert_no_selector "dialog.lp-dash-quest-sheet"

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/objective-quantity-optin-today-mobile.png")

    patch_practice_task!(@tracked, amount: "12")
    visit dashboard_path
    assert_battle_row!(title: "Read Atomic Habits", todo: @todo)
    assert_equal BigDecimal("19"), @section.reload.current_amount
    assert @tracked.reload.completed?

    patch_practice_task!(@plain)
    visit dashboard_path
    assert_battle_row_absent!(title: "Read Atomic Habits")
    assert_no_selector ".lp-dash-done-fold"
    assert @plain.reload.completed?
    assert @host.reload.completed?
    assert_equal BigDecimal("19"), @section.reload.current_amount

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @folder.id)
    open_project_objectives(@folder)
    within("dialog#section-objectives-#{@folder.id}") do
      open_mountain_list_fallback!
      assert_selector ".lp-climb-path__quest-title", text: /Read Atomic Habits/i
      assert_selector ".lp-climb-path__quest-add-track", text: /Track progress \(pages\)/i
    end
    page.save_screenshot("/opt/cursor/artifacts/screenshots/objective-quantity-toggle-mountain-mobile.png")
  end
end
