# frozen_string_literal: true

require "test_helper"

module Battles
  class WinsOnLocalDateEverTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @user.daily_todos.delete_all
      @zone = "Europe/Berlin"
      @date = Date.new(2026, 8, 6)
    end

    test "ever? is false with no wins and counts_by_date empty" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
        @user.strategy_goals.battles.update_all(completed_at: nil, repeat: nil)

        counts = WinsOnLocalDate.counts_by_date(
          user: @user,
          from: @date,
          to: @date,
          time_zone: @zone
        )
        assert_equal 0, counts[@date].to_i
        refute WinsOnLocalDate.ever?(user: @user)
      end
    end

    test "one-shot win: counts_by_date positive iff ever?" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
        seed_climb!(@user, today_mission: "One shot ever")
        battle = @user.strategy_goals.find_by!(horizon: "day", title: "One shot ever")
        battle.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 5, 9, 0, 0))

        counts = WinsOnLocalDate.counts_by_date(
          user: @user,
          from: Date.new(2026, 8, 5),
          to: Date.new(2026, 8, 5),
          time_zone: @zone
        )
        assert_operator counts[Date.new(2026, 8, 5)], :>, 0
        assert WinsOnLocalDate.ever?(user: @user)
      end
    end

    test "recurring win: counts_by_date positive iff ever?" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
        seed_climb!(@user, today_mission: "Stretch daily ever")
        battle = @user.strategy_goals.find_by!(horizon: "day", title: "Stretch daily ever")
        battle.update!(repeat: "daily")
        Strategy::CascadeToDaily.call(user: @user, life_area: battle.life_area, from: @date, to: @date)
        todo = @user.daily_todos.for_day(@date).find_by!(strategy_goal_id: battle.id)
        todo.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 6, 10, 0, 0))

        counts = WinsOnLocalDate.counts_by_date(
          user: @user,
          from: @date,
          to: @date,
          time_zone: @zone
        )
        assert_equal 1, counts[@date]
        assert WinsOnLocalDate.ever?(user: @user)
      end
    end
  end
end
