# frozen_string_literal: true

require "test_helper"

class DailyTodoQuantityUndoTest < ActionDispatch::IntegrationTest
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
      target_amount: 100, unit: "pages"
    )
    leaf = practice_leaf_for!(@project)
    @day = @user.strategy_goals.create!(
      life_area: @area, parent: leaf, horizon: "day", title: "Read",
      scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    @todo = @user.daily_todos.find_by!(strategy_goal_id: @day.id, scheduled_on: Date.current)
    sign_in_as(@user)
  end

  test "undoing a completed battle reverses its quantity log" do
    Strategy::Quantity::Log.call(
      project: @project, amount: 12, user: @user, source_day: @day, daily_todo: @todo
    )
    @todo.update!(completed_at: Time.current)
    @day.complete!

    assert_equal BigDecimal("12"), @project.reload.current_amount

    post complete_daily_todo_path(@todo)

    assert_nil StrategyQuantityLog.find_by(daily_todo_id: @todo.id)
    assert_equal BigDecimal("0"), @project.reload.current_amount
    assert_nil @todo.reload.completed_at
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password12345" }
  end
end
