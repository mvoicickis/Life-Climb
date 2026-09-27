# frozen_string_literal: true

require "test_helper"

module Notifications
  class BattleWinsOnLocalDateTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @user.daily_todos.delete_all
      @date = Date.new(2026, 8, 6)
      @zone = "Europe/Berlin"
    end

    test "daily battle todo completed on date counts as win" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
        seed_climb!(@user, today_mission: "Stretch daily")
        battle = @user.strategy_goals.find_by!(horizon: "day", title: "Stretch daily")
        battle.update!(repeat: "daily")
        Strategy::CascadeToDaily.call(user: @user, life_area: battle.life_area, from: @date, to: @date)
        todo = @user.daily_todos.for_day(@date).find_by!(strategy_goal_id: battle.id)
        todo.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 6, 10, 0, 0))

        assert BattleWinsOnLocalDate.any?(user: @user, date: @date, time_zone: @zone)
      end
    end

    test "one-shot completed on local date counts as win" do
      seed_climb!(@user, today_mission: "Ship auth")
      battle = @user.strategy_goals.find_by!(horizon: "day", title: "Ship auth")
      battle.update!(
        completed_at: Time.find_zone!(@zone).local(2026, 8, 6, 9, 0, 0)
      )

      assert BattleWinsOnLocalDate.any?(user: @user, date: @date, time_zone: @zone)
    end

    test "one-shot completed yesterday does not count" do
      seed_climb!(@user, today_mission: "Yesterday win")
      battle = @user.strategy_goals.find_by!(horizon: "day", title: "Yesterday win")
      battle.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 5, 9, 0, 0))

      refute BattleWinsOnLocalDate.any?(user: @user, date: @date, time_zone: @zone)
    end

    test "completed ad-hoc todo without strategy link does not count" do
      @user.daily_todos.create!(
        title: "Personal errand",
        aspect_key: "career",
        scheduled_on: @date,
        position: 0,
        completed_at: Time.find_zone!(@zone).local(2026, 8, 6, 10, 0, 0)
      )

      refute BattleWinsOnLocalDate.any?(user: @user, date: @date, time_zone: @zone)
    end

    test "no wins when nothing completed" do
      refute BattleWinsOnLocalDate.any?(user: @user, date: @date, time_zone: @zone)
    end
  end
end
