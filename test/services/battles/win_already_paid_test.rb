# frozen_string_literal: true

require "test_helper"

class Battles::WinAlreadyPaidTest < ActiveSupport::TestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    seed_climb!(@user, today_mission: "Guard check")
    @todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Guard check")
    @battle = @todo.strategy_goal
  end

  test "miss and shield rows do not count as paid" do
    @user.life_point_ledgers.create!(amount: -15, reason: "miss", source: @todo)
    refute Battles::WinAlreadyPaid.for_todo?(@todo)

    @user.life_point_ledgers.create!(amount: 0, reason: "shield", source: @todo)
    refute Battles::WinAlreadyPaid.for_todo?(@todo)
  end

  test "positive DailyTodo or StrategyGoal ledger counts for both paths" do
    refute Battles::WinAlreadyPaid.for_todo?(@todo)
    refute Battles::WinAlreadyPaid.for_battle?(@battle, todo: @todo)

    @user.life_point_ledgers.create!(amount: 30, reason: "win", source: @todo)
    assert Battles::WinAlreadyPaid.for_todo?(@todo)
    assert Battles::WinAlreadyPaid.for_battle?(@battle, todo: @todo)

    LifePointLedger.where(source: @todo).delete_all
    @user.life_point_ledgers.create!(amount: 30, reason: "mountain", source: @battle)
    assert Battles::WinAlreadyPaid.for_todo?(@todo)
    assert Battles::WinAlreadyPaid.for_battle?(@battle, todo: @todo)
  end
end
