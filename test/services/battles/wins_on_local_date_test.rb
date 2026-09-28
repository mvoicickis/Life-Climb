# frozen_string_literal: true

require "test_helper"

module Battles
  class WinsOnLocalDateTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @user.daily_todos.delete_all
      @date = Date.new(2026, 8, 6)
      @zone = "Europe/Berlin"
    end

    test "count_for_date matches notification rules for daily battle todo" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
        seed_climb!(@user, today_mission: "Stretch daily")
        battle = @user.strategy_goals.find_by!(horizon: "day", title: "Stretch daily")
        battle.update!(repeat: "daily")
        Strategy::CascadeToDaily.call(user: @user, life_area: battle.life_area, from: @date, to: @date)
        todo = @user.daily_todos.for_day(@date).find_by!(strategy_goal_id: battle.id)
        todo.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 6, 10, 0, 0))

        assert_equal 1, WinsOnLocalDate.count_for_date(user: @user, date: @date, time_zone: @zone)
      end
    end

    test "counts_by_date batches a range without per-day queries" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
        seed_climb!(@user, today_mission: "Range win")
        battle = @user.strategy_goals.find_by!(horizon: "day", title: "Range win")
        battle.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 5, 9, 0, 0))

        from = Date.new(2026, 8, 1)
        to = Date.new(2026, 8, 31)
        queries = 0
        callback = lambda do |_name, _start, _finish, _id, payload|
          queries += 1 if payload[:sql].present?
        end

        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
          counts = WinsOnLocalDate.counts_by_date(user: @user, from: from, to: to, time_zone: @zone)
          assert_equal 1, counts[Date.new(2026, 8, 5)]
          assert_equal 0, counts[Date.new(2026, 8, 6)]
        end

        assert_operator queries, :<=, 6, "expected batched queries, got #{queries}"
      end
    end
  end
end
