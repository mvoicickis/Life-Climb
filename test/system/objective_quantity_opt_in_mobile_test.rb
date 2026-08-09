# frozen_string_literal: true

require "application_system_test_case"

class ObjectiveQuantityOptInMobileTest < ApplicationSystemTestCase
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
      horizon: "project", title: "Read Atomic Habits",
      position: @plan.children.maximum(:position).to_i + 1,
      target_amount: 700, unit: "pages", current_amount: 7
    )
    @folder = @section.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Volume 0", position: 0
    )
    @host = Strategy::EnsureFolderQuest.call(folder: @folder)
    @tracked = @host.practice_tasks.create!(
      user: @user, title: "Read chapter 3", position: 0, track_quantity: true
    )
    @plain = @host.practice_tasks.create!(
      user: @user, title: "Review notes", position: 1, track_quantity: false
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
  end

  test "mobile opted-in objective asks for amount; plain stays one-tap; day finishes" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-tcard.is-quest", wait: 5

    assert_selector ".lp-dash-tcard__objective[data-controller='quantity-complete']", text: /Read chapter 3/
    assert_no_selector ".lp-dash-tcard__objective[data-controller='quantity-complete']", text: /Review notes/

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/objective-quantity-optin-today-mobile.png")

    find("button.lp-dash-tcard__win[aria-label='Complete Read chapter 3']").click
    assert_selector "dialog.lp-quantity-complete[open]", wait: 3
    assert_selector "dialog.lp-quantity-complete[open] .lp-strategy-sheet__title", text: /How many pages/i
    page.save_screenshot("/opt/cursor/artifacts/screenshots/objective-quantity-dialog-mobile.png")

    within("dialog.lp-quantity-complete[open]") do
      fill_in "dialog_amount", with: "12"
      click_button I18n.t("strategy.quantity.log_confirm")
    end

    assert_selector ".lp-dash-tcard__objective.is-done", text: /Read chapter 3/, wait: 5
    assert_equal BigDecimal("19"), @section.reload.current_amount
    assert @tracked.reload.completed?

    find("button.lp-dash-tcard__win[aria-label='Complete Review notes']").click
    assert_no_selector "dialog.lp-quantity-complete[open]"
    assert_selector ".lp-dash-tcard.is-quest.is-done", text: /Volume 0/i, wait: 5
    assert @plain.reload.completed?
    assert @host.reload.completed?
    assert_equal BigDecimal("19"), @section.reload.current_amount

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @folder.id)
    assert_selector ".lp-climb-path__quests[open]", wait: 5
    assert_selector ".lp-climb-path__quest-title", text: /Volume 0/i
    assert_selector ".lp-climb-path__quest-add-track", text: /Track progress \(pages\)/i
    page.save_screenshot("/opt/cursor/artifacts/screenshots/objective-quantity-toggle-mountain-mobile.png")
  end
end
