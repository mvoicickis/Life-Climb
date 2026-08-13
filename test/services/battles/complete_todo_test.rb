# frozen_string_literal: true

require "test_helper"

class Battles::CompleteTodoTest < ActiveSupport::TestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    seed_climb!(@user, today_mission: "Ship the form")
    @todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Ship the form")
    @session = {}
    @user.update!(total_points: 100)
  end

  test "complete then uncomplete then complete awards AP only once" do
    assert_difference -> { @user.reload.life_points }, GameRules::BATTLE_TODO_LP do
      Battles::CompleteTodo.call(todo: @todo, user: @user, session: @session)
    end
    assert @todo.reload.completed?
    assert_equal 1, positive_todo_ledgers.count

    assert_no_difference -> { @user.reload.life_points } do
      Battles::UncompleteTodo.call(todo: @todo, user: @user)
    end
    assert_nil @todo.reload.completed_at
    assert_equal 1, positive_todo_ledgers.count

    assert_no_difference -> { @user.reload.life_points } do
      Battles::CompleteTodo.call(todo: @todo, user: @user, session: @session)
    end
    assert @todo.reload.completed?
    assert_equal 1, positive_todo_ledgers.count
  end

  test "positive ledger already present with incomplete todo completes without awarding" do
    LifePoints::Award.call(
      user: @user,
      amount: GameRules::BATTLE_TODO_LP,
      reason: "prior win",
      source: @todo
    )
    @todo.update!(completed_at: nil)
    points_before = @user.reload.life_points
    ledgers_before = positive_todo_ledgers.count

    result = Battles::CompleteTodo.call(todo: @todo, user: @user, session: @session)

    assert @todo.reload.completed?
    assert_equal 0, result.awarded
    assert_equal points_before, @user.reload.life_points
    assert_equal ledgers_before, positive_todo_ledgers.count
  end

  test "miss ledger amount <= 0 does not block the first real win" do
    @user.life_point_ledgers.create!(
      amount: -15,
      reason: "missed window",
      source: @todo
    )
    @todo.update!(completed_at: nil, miss_settled_at: Time.current)

    assert_difference -> { @user.reload.life_points }, GameRules::BATTLE_TODO_LP do
      result = Battles::CompleteTodo.call(todo: @todo, user: @user, session: @session)
      assert_equal GameRules::BATTLE_TODO_LP, result.awarded
    end
    assert @todo.reload.completed?
    assert_equal 1, positive_todo_ledgers.count
  end

  test "shield ledger amount 0 does not block the first real win" do
    @user.life_point_ledgers.create!(
      amount: 0,
      reason: "shielded miss",
      source: @todo
    )
    @todo.update!(completed_at: nil, miss_settled_at: Time.current)

    assert_difference -> { @user.reload.life_points }, GameRules::BATTLE_TODO_LP do
      Battles::CompleteTodo.call(todo: @todo, user: @user, session: @session)
    end
    assert_equal 1, positive_todo_ledgers.count
  end

  test "complete then undo then miss then re-complete leaves net miss debit only" do
    # +30 on win, keep on undo, -15 on miss, skip on re-complete → net +15
    Battles::CompleteTodo.call(todo: @todo, user: @user, session: @session)
    points_after_win = @user.reload.life_points

    Battles::UncompleteTodo.call(todo: @todo, user: @user)
    assert_equal points_after_win, @user.reload.life_points

    @todo.update!(start_time: "09:00", end_time: "10:00", miss_settled_at: nil)
    @user.update!(day_shields_available: 0, day_shield_on: Date.current)
    now = Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 11, 0, 0)
    Today::MissSettlement.apply!(user: @user, date: Date.current, now: now)
    expected = points_after_win - (GameRules::BATTLE_TODO_LP / 2)
    assert_equal expected, @user.reload.life_points

    assert_no_difference -> { @user.reload.life_points } do
      Battles::CompleteTodo.call(todo: @todo.reload, user: @user, session: @session)
    end
    assert @todo.reload.completed?
    assert_equal expected, @user.reload.life_points
  end

  test "battle StrategyGoal win blocks CompleteTodo re-award" do
    day = @todo.strategy_goal
    LifePoints::Award.call(
      user: @user,
      amount: GameRules::BATTLE_TODO_LP,
      reason: "mountain win",
      source: day
    )
    @todo.update!(completed_at: nil)
    day.reopen! if day.completed?

    assert_no_difference -> { @user.reload.life_points } do
      result = Battles::CompleteTodo.call(todo: @todo, user: @user, session: @session)
      assert_equal 0, result.awarded
    end
    assert @todo.reload.completed?
  end

  private

  def positive_todo_ledgers
    LifePointLedger.where(source: @todo).where("amount > 0")
  end
end
