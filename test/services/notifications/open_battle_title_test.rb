# frozen_string_literal: true

require "test_helper"

module Notifications
  class OpenBattleTitleTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @user.daily_todos.delete_all
      @user.life_journeys.delete_all
      @user.strategy_goals.delete_all
    end

    test "prefers linked incomplete todo" do
      seed_climb!(@user, today_mission: "Camp battle")
      date = Date.new(2026, 8, 6)
      battle = @user.strategy_goals.where(horizon: "day").order(:id).last
      @user.daily_todos.delete_all
      @user.daily_todos.create!(
        title: "First todo",
        aspect_key: "career",
        scheduled_on: date,
        position: 0,
        lp_reward: 10,
        strategy_goal_id: battle.id,
        tag: "strategy"
      )

      assert_equal "First todo", OpenBattleTitle.for(user: @user, on: date)
    end

    test "falls back to due strategy goal when no todos" do
      travel_to Time.zone.local(2026, 8, 6, 12, 0, 0) do
        seed_climb!(@user, today_mission: "Read for ten minutes")
        date = Date.current
        @user.daily_todos.delete_all
        battle = @user.strategy_goals.where(horizon: "day").order(:id).last
        battle.update!(scheduled_on: date)

        assert_equal "Read for ten minutes", OpenBattleTitle.for(user: @user, on: date)
      end
    end

    test "skips strategy goal already won on date" do
      travel_to Time.zone.local(2026, 8, 6, 12, 0, 0) do
        seed_climb!(@user, today_mission: "Done battle")
        date = Date.current
        @user.daily_todos.delete_all
        battle = @user.strategy_goals.where(horizon: "day").order(:id).last
        battle.update!(scheduled_on: date, completed_at: Time.zone.local(2026, 8, 6, 7, 0, 0))

        assert_nil OpenBattleTitle.for(user: @user, on: date)
      end
    end

    test "does not create records" do
      travel_to Time.zone.local(2026, 8, 6, 12, 0, 0) do
        seed_climb!(@user, today_mission: "Quiet step")
        date = Date.current
        @user.daily_todos.delete_all
        todo_count = DailyTodo.count

        OpenBattleTitle.for(user: @user, on: date)

        assert_equal todo_count, DailyTodo.count
      end
    end
  end
end
