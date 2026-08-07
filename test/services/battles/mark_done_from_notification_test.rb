# frozen_string_literal: true

require "test_helper"

module Battles
  class MarkDoneFromNotificationTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      seed_climb!(@user, area_key: "money", today_mission: "Review budget")
      @session = {}
    end

    test "completes existing incomplete todo for today" do
      todo = @user.daily_todos.for_day.incomplete.first
      assert todo

      result = MarkDoneFromNotification.call(user: @user, session: @session)
      refute result.nothing_to_mark
      assert result.todo.completed?
      assert_equal todo.id, result.todo.id
    end

    test "returns nothing_to_mark without fabricating a battle" do
      @user.daily_todos.for_day.find_each do |todo|
        todo.update!(completed_at: Time.current)
      end
      @user.strategy_goals.where(horizon: "day", scheduled_on: Date.current).find_each do |day|
        day.update!(completed_at: Time.current) unless day.completed?
      end
      @user.daily_todos.for_day.incomplete.delete_all

      before_todos = @user.daily_todos.for_day.count
      before_days = @user.strategy_goals.where(horizon: "day", scheduled_on: Date.current).count

      result = MarkDoneFromNotification.call(user: @user, session: @session, category: "money")
      assert result.nothing_to_mark
      assert_nil result.todo
      assert_equal before_todos, @user.daily_todos.for_day.count
      assert_equal before_days, @user.strategy_goals.where(horizon: "day", scheduled_on: Date.current).count
    end
  end
end
