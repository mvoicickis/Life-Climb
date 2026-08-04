# frozen_string_literal: true

require "test_helper"

class Strategy::Quantity::UnlogTest < ActiveSupport::TestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @area = life_areas(:one_self)
    @goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    @plan = @user.strategy_goals.create!(
      life_area: @area, parent: @goal, horizon: "plan", title: "P", position: 0
    )
    @project = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Debt",
      position: 0, target_amount: 15_000, unit: "€"
    )
    @leaf = practice_leaf_for!(@project)
    @day = @user.strategy_goals.create!(
      life_area: @area, parent: @leaf, horizon: "day", title: "Pay installment",
      scheduled_on: Date.current, position: 0
    )
    @todo = @user.daily_todos.create!(
      title: @day.title,
      aspect_key: "self",
      scheduled_on: Date.current,
      strategy_goal: @day,
      completed_at: Time.current
    )
  end

  test "undo deletes log and subtracts amount without going below zero" do
    Strategy::Quantity::Log.call(
      project: @project, amount: 500, user: @user, source_day: @day, daily_todo: @todo
    )
    assert_equal BigDecimal("500"), @project.reload.current_amount

    Strategy::Quantity::Unlog.call(daily_todo: @todo)

    assert_nil StrategyQuantityLog.find_by(daily_todo_id: @todo.id)
    assert_equal BigDecimal("0"), @project.reload.current_amount
    assert_equal 0, Strategy::Progress.percent(@project)
  end

  test "undo reopens project when total falls below target" do
    Strategy::Quantity::Log.call(
      project: @project, amount: 15_000, user: @user, source_day: @day, daily_todo: @todo
    )
    assert @project.reload.completed?
    assert @plan.reload.completed?

    Strategy::Quantity::Unlog.call(daily_todo: @todo)

    assert_not @project.reload.completed?
    assert_equal BigDecimal("0"), @project.current_amount
    assert_not @plan.reload.completed?
  end

  test "undo floors current_amount at zero" do
    Strategy::Quantity::Log.call(
      project: @project, amount: 100, user: @user, source_day: @day, daily_todo: @todo
    )
    # Simulate drift so subtract would go negative without a floor.
    @project.update_columns(current_amount: 50)

    Strategy::Quantity::Unlog.call(daily_todo: @todo)

    assert_equal BigDecimal("0"), @project.reload.current_amount
  end
end
