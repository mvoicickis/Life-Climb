# frozen_string_literal: true

require "application_system_test_case"

class QuantityBattleCompleteMobileTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(390, 844)

    seed_climb!(@user, today_mission: "Write tests")
    @area = @user.primary_focused_journey.life_area
    goal = @user.strategy_goals.for_kind("goal").roots.first
    plan = goal.children.find(&:plan?)
    @project = @user.strategy_goals.create!(
      life_area: @area, parent: plan, horizon: "project", title: "Read book",
      position: plan.children.maximum(:position).to_i + 1,
      target_amount: 700, unit: "pages", current_amount: 7
    )
    leaf = practice_leaf_for!(@project)
    @day = @user.strategy_goals.create!(
      life_area: @area, parent: leaf, horizon: "day", title: "Read chapter",
      scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    @todo = @user.daily_todos.find_by!(strategy_goal_id: @day.id, scheduled_on: Date.current)
  end

  test "mobile quantified checkbox opens amount dialog then logs progress" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-battle", wait: 5

    assert_selector ".lp-dash-check", minimum: 1
    assert_no_selector "dialog.lp-quantity-complete[open]"
    # Checkbox-only flow: no batch Complete Today control.
    assert_no_selector "form[action='#{battle_completion_path}']"

    find("li[data-controller='quantity-complete'] button.lp-dash-check").click
    assert_selector "dialog.lp-quantity-complete[open]", wait: 3
    assert_selector "dialog.lp-quantity-complete[open] .lp-strategy-sheet__title",
                    text: /How many pages/i

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/quantity-battle-amount-dialog-mobile.png")

    within("dialog.lp-quantity-complete[open]") do
      fill_in "dialog_amount", with: "12"
      click_button I18n.t("strategy.quantity.log_confirm")
    end

    assert_selector ".lp-dash-battle", wait: 5
    assert_no_selector "dialog.lp-quantity-complete[open]"
    assert_selector ".lp-dash-battle__done", text: /Read chapter/i, visible: :all, wait: 5

    @project.reload
    @todo.reload
    assert @todo.completed?
    assert_equal BigDecimal("19"), @project.current_amount
    log = StrategyQuantityLog.find_by!(daily_todo_id: @todo.id)
    assert_equal BigDecimal("12"), log.amount
  end

  test "mobile non-quantified checkbox still completes in one tap" do
    plain = @user.strategy_goals.create!(
      life_area: @area,
      parent: @project.parent,
      horizon: "project",
      title: "Plain camp",
      position: @project.parent.children.maximum(:position).to_i + 1
    )
    plain_leaf = practice_leaf_for!(plain)
    plain_day = @user.strategy_goals.create!(
      life_area: @area, parent: plain_leaf, horizon: "day", title: "Ship PR",
      scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    plain_todo = @user.daily_todos.find_by!(strategy_goal_id: plain_day.id, scheduled_on: Date.current)

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-battle", wait: 5

    find("button.lp-dash-check[aria-label='Complete Ship PR']").click
    assert_no_selector "dialog.lp-quantity-complete[open]"
    assert_selector ".lp-dash-battle__done", text: /Ship PR/i, visible: :all, wait: 5
    assert plain_todo.reload.completed?
    assert_equal BigDecimal("7"), @project.reload.current_amount
    assert_nil StrategyQuantityLog.find_by(daily_todo_id: plain_todo.id)
  end
end
