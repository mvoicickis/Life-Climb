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
      refute result.created
      assert result.todo.completed?
      assert_equal todo.id, result.todo.id
    end

    test "creates then completes when no incomplete battle today" do
      @user.daily_todos.for_day.find_each do |todo|
        todo.update!(completed_at: Time.current)
      end
      # Also clear day goals scheduled today so cascade doesn't re-feed incomplete ones oddly
      @user.strategy_goals.where(horizon: "day", scheduled_on: Date.current).find_each do |day|
        day.update!(completed_at: Time.current) unless day.completed?
      end
      @user.daily_todos.for_day.incomplete.delete_all

      money_examples = Array(I18n.t("strategy.first_climb.examples.money.action"))

      result = MarkDoneFromNotification.call(user: @user, session: @session, category: "money")
      assert result.created
      assert result.todo.completed?
      assert_includes money_examples, result.title
    end
  end
end
