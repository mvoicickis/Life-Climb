# frozen_string_literal: true

require "test_helper"

class DailyTodoQuantityCompleteTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    seed_climb!(@user)
    @area = @user.primary_focused_journey.life_area
    goal = @user.strategy_goals.for_kind("goal").roots.first
    plan = goal.children.find(&:plan?)
    @project = @user.strategy_goals.create!(
      life_area: @area, parent: plan, horizon: "project", title: "Pages",
      position: plan.children.maximum(:position).to_i + 1,
      target_amount: 100, unit: "pages", current_amount: 10
    )
    leaf = practice_leaf_for!(@project)
    @day = @user.strategy_goals.create!(
      life_area: @area, parent: leaf, horizon: "day", title: "Read chapter",
      scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    @todo = @user.daily_todos.find_by!(strategy_goal_id: @day.id, scheduled_on: Date.current)
    sign_in_as(@user)
  end

  test "today V2 shows quantity sheet for quantified battles only" do
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

    get dashboard_path
    assert_response :success

    assert_select ".lp-today-v2-row[data-todo-id=?][data-controller*='quantity-complete']", @todo.id.to_s
    assert_select ".lp-today-v2-row[data-todo-id=?] dialog.lp-quantity-complete", @todo.id.to_s
    assert_select ".lp-today-v2-row[data-todo-id=?] form[data-action*='quantity-complete#intercept']",
                  @todo.id.to_s
    assert_select ".lp-today-v2-row[data-todo-id=?][data-controller*='quantity-complete']", plain_todo.id.to_s, count: 0
    assert_select ".lp-today-v2-row[data-todo-id=?] form.lp-today-v2-row__check-form[action=?]",
                  plain_todo.id.to_s,
                  complete_daily_todo_path(plain_todo)
  end

  test "completing a quantified battle logs amount and updates current_amount" do
    assert_difference -> { StrategyQuantityLog.count }, 1 do
      post complete_daily_todo_path(@todo), params: { amount: "12" }
    end

    assert_redirected_to dashboard_path
    assert @todo.reload.completed?
    assert_equal BigDecimal("22"), @project.reload.current_amount

    log = StrategyQuantityLog.find_by!(daily_todo_id: @todo.id)
    assert_equal BigDecimal("12"), log.amount
    assert_equal "pages", log.unit
    assert_equal @project.id, log.strategy_goal_id
    assert_equal @day.id, log.source_day_id
    assert_equal Date.current, log.logged_on
  end

  test "quantified battle without amount stays open" do
    assert_no_difference -> { StrategyQuantityLog.count } do
      post complete_daily_todo_path(@todo)
    end

    assert_redirected_to dashboard_path
    assert_nil @todo.reload.completed_at
    assert_equal BigDecimal("10"), @project.reload.current_amount
    follow_redirect!
    assert_match(/Enter how many pages/i, response.body)
  end

  test "completing a non-quantified battle stays one-tap with no log" do
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

    assert_no_difference -> { StrategyQuantityLog.count } do
      post complete_daily_todo_path(plain_todo)
    end

    assert_redirected_to dashboard_path
    assert plain_todo.reload.completed?
    assert_equal BigDecimal("10"), @project.reload.current_amount
  end

  test "undo after quantified complete reverses log and current_amount" do
    post complete_daily_todo_path(@todo), params: { amount: "15" }
    assert_equal BigDecimal("25"), @project.reload.current_amount
    assert @todo.reload.completed?

    post complete_daily_todo_path(@todo)

    assert_nil StrategyQuantityLog.find_by(daily_todo_id: @todo.id)
    assert_equal BigDecimal("10"), @project.reload.current_amount
    assert_nil @todo.reload.completed_at
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password12345" }
  end
end
