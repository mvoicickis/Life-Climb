# frozen_string_literal: true

require "test_helper"

class Strategy::EnsureDayForTodoTest < ActiveSupport::TestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @journey = seed_climb!(@user, today_mission: "Ship auth")
  end

  test "returns existing strategy_goal when already linked" do
    todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Ship auth")
    day = todo.strategy_goal
    assert day.present?

    assert_no_difference -> { @user.strategy_goals.where(horizon: "day").count } do
      assert_equal day, Strategy::EnsureDayForTodo.call(todo: todo)
    end
  end

  test "provisions a day goal and links orphan todo without duplicating DailyTodo" do
    orphan = @user.daily_todos.create!(
      title: "Orphan MVP battle",
      aspect_key: "career",
      scheduled_on: Date.current,
      position: 99,
      lp_reward: GameRules::BATTLE_TODO_LP
    )
    assert_nil orphan.strategy_goal_id

    assert_difference -> { @user.strategy_goals.where(horizon: "day").count }, 1 do
      assert_no_difference -> { @user.daily_todos.for_day(Date.current).count } do
        day = Strategy::EnsureDayForTodo.call(todo: orphan)
        assert_equal day.id, orphan.reload.strategy_goal_id
        assert_equal "Orphan MVP battle", day.title
      end
    end

    assert_equal 1, @user.daily_todos.where(title: "Orphan MVP battle", scheduled_on: Date.current).count

    # Idempotent retry
    assert_no_difference -> { @user.strategy_goals.where(horizon: "day").count } do
      assert_no_difference -> { @user.daily_todos.for_day(Date.current).count } do
        Strategy::EnsureDayForTodo.call(todo: orphan.reload)
      end
    end
    assert_equal 1, @user.daily_todos.where(title: "Orphan MVP battle", scheduled_on: Date.current).count
  end
end
