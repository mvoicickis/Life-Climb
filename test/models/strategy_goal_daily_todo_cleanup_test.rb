# frozen_string_literal: true

require "test_helper"

class StrategyGoalDailyTodoCleanupTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @area = @user.life_areas.first || @user.life_areas.create!(key: "career", title: "Career")
    @goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    @plan = @user.strategy_goals.create!(
      life_area: @area, parent: @goal, horizon: "plan", title: "P", position: 0
    )
    @section = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Section", position: 0
    )
    @quest = @user.strategy_goals.create!(
      life_area: @area, parent: @section, horizon: "project", title: "Quest", position: 0
    )
    @day = @user.strategy_goals.create!(
      life_area: @area, parent: @quest, horizon: "day", title: "Checklist",
      scheduled_on: Date.current, position: 0
    )
  end

  test "destroying a day removes its open DailyTodo" do
    todo = @user.daily_todos.create!(
      title: "Open battle",
      aspect_key: "career",
      scheduled_on: Date.current,
      strategy_goal: @day,
      position: 0,
      lp_reward: 30,
      tag: "strategy"
    )

    assert_difference -> { @user.daily_todos.count }, -1 do
      @day.destroy!
    end
    assert_not DailyTodo.exists?(todo.id)
  end

  test "destroying a day keeps completed DailyTodo and nullifies the link" do
    todo = @user.daily_todos.create!(
      title: "Done battle",
      aspect_key: "career",
      scheduled_on: Date.current,
      strategy_goal: @day,
      position: 0,
      lp_reward: 30,
      tag: "strategy",
      completed_at: Time.current
    )

    assert_no_difference -> { @user.daily_todos.count } do
      @day.destroy!
    end
    todo.reload
    assert todo.completed?
    assert_nil todo.strategy_goal_id
    assert_equal "Done battle", todo.title
  end

  test "destroying a quest removes open checklist DailyTodo via child day destroy" do
    todo = @user.daily_todos.create!(
      title: "Quest shell",
      aspect_key: "career",
      scheduled_on: Date.current,
      strategy_goal: @day,
      position: 0,
      lp_reward: 30,
      tag: "strategy"
    )

    assert_difference -> { @user.daily_todos.incomplete.count }, -1 do
      @quest.destroy!
    end
    assert_not DailyTodo.exists?(todo.id)
    assert_not StrategyGoal.exists?(@day.id)
  end

  test "destroying a quest with open host and completed sibling day cleans both correctly" do
    open_todo = @user.daily_todos.create!(
      title: "Open shell",
      aspect_key: "career",
      scheduled_on: Date.current,
      strategy_goal: @day,
      position: 0,
      lp_reward: 30,
      tag: "strategy"
    )
    done_day = @user.strategy_goals.create!(
      life_area: @area, parent: @quest, horizon: "day", title: "Done sibling",
      scheduled_on: Date.current, position: 1
    )
    done_todo = @user.daily_todos.create!(
      title: "Done shell",
      aspect_key: "career",
      scheduled_on: Date.current,
      strategy_goal: done_day,
      position: 1,
      lp_reward: 30,
      tag: "strategy",
      completed_at: Time.current
    )

    @quest.destroy!

    assert_not DailyTodo.exists?(open_todo.id)
    assert DailyTodo.exists?(done_todo.id)
    assert_nil done_todo.reload.strategy_goal_id
    assert done_todo.completed?
  end
end
