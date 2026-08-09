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

  test "mobile quantified battle uses amount input then Win" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-timeline", wait: 5

    card = find(".lp-dash-tcard[data-todo-id='#{@todo.id}']")
    within(card) do
      find(".lp-dash-tcard__amount").set("12")
      click_button "Win"
    end

    assert_selector ".lp-dash-tcard.is-done[data-todo-id='#{@todo.id}']", wait: 5

    @project.reload
    @todo.reload
    assert @todo.completed?
    assert_equal BigDecimal("19"), @project.current_amount
    log = StrategyQuantityLog.find_by!(daily_todo_id: @todo.id)
    assert_equal BigDecimal("12"), log.amount
  end

  test "mobile non-quantified Win still completes in one tap" do
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
    assert_selector ".lp-dash-timeline", wait: 5

    find("button.lp-dash-tcard__win[aria-label='Win Ship PR']").click
    assert_selector ".lp-dash-tcard.is-done[data-todo-id='#{plain_todo.id}']", wait: 5
    assert plain_todo.reload.completed?
    assert_equal BigDecimal("7"), @project.reload.current_amount
    assert_nil StrategyQuantityLog.find_by(daily_todo_id: plain_todo.id)
  end
end
