# frozen_string_literal: true

require "test_helper"

class StrategyGoalDailyTodoCleanupTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @area = @user.life_areas.first || @user.life_areas.create!(key: "career", title: "Career")
    @journey = @user.life_journeys.find_by(life_area_id: @area.id) || @user.life_journeys.create!(
      life_area: @area,
      title: "Climb",
      ideal_scene: "Done",
      current_reality: "Now",
      status: "active"
    )
    @goal = @user.strategy_goals.create!(life_area: @area, life_journey: @journey, horizon: "goal", title: "G", position: 0)
    @plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan", title: "P", position: 0
    )
    @section = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "Section", position: 0
    )
    @day = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @section, horizon: "day", title: "Checklist",
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

  test "destroying a path camp reparents the day and keeps its open DailyTodo" do
    todo = @user.daily_todos.create!(
      title: "Quest shell",
      aspect_key: "career",
      scheduled_on: Date.current,
      strategy_goal: @day,
      position: 0,
      lp_reward: 30,
      tag: "strategy"
    )

    assert_no_difference -> { @user.daily_todos.incomplete.count } do
      @section.destroy!
    end
    assert DailyTodo.exists?(todo.id)
    assert StrategyGoal.exists?(@day.id)
    @day.reload
    assert @day.parent.holding?
    assert_equal @day.id, todo.reload.strategy_goal_id
  end

  test "destroying a path camp keeps open and completed DailyTodos on surviving days" do
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
      life_area: @area, life_journey: @journey, parent: @section, horizon: "day", title: "Done sibling",
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

    @section.destroy!

    assert DailyTodo.exists?(open_todo.id)
    assert DailyTodo.exists?(done_todo.id)
    assert_equal @day.id, open_todo.reload.strategy_goal_id
    assert_equal done_day.id, done_todo.reload.strategy_goal_id
    assert done_todo.completed?
    assert @day.reload.parent.holding?
    assert done_day.reload.parent.holding?
  end
end
