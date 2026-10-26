# frozen_string_literal: true

require "test_helper"

module Battles
  class DaysInARowTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @user.daily_todos.delete_all
      @user.strategy_goals.delete_all
      @zone = "Europe/Berlin"
      @user.create_notification_preference!(time_zone: @zone) unless @user.notification_preference
      @user.notification_preference.update!(time_zone: @zone)
      @today = Date.new(2026, 8, 6)
    end

    test "empty history is zero" do
      travel_to zone_time(2026, 8, 6, 12) do
        assert_equal 0, DaysInARow.count(user: @user)
      end
    end

    test "one-shot win today is one day" do
      travel_to zone_time(2026, 8, 6, 12) do
        complete_one_shot!("Ship auth", on: @today)
        assert_equal 1, DaysInARow.count(user: @user)
      end
    end

    test "consecutive earlier local days count" do
      travel_to zone_time(2026, 8, 6, 12) do
        complete_one_shot!("Day before yesterday", on: @today - 2)
        complete_one_shot!("Yesterday", on: @today - 1)
        complete_one_shot!("Today", on: @today)
        assert_equal 3, DaysInARow.count(user: @user)
      end
    end

    test "daily battle todos on scheduled_on count" do
      travel_to zone_time(2026, 8, 6, 12) do
        seed_climb!(@user, today_mission: "Stretch daily")
        battle = @user.strategy_goals.find_by!(horizon: "day", title: "Stretch daily")
        from = @today - 1
        battle.update!(repeat: "daily", scheduled_on: from)
        Strategy::CascadeToDaily.call(user: @user, life_area: battle.life_area, from: from, to: @today)
        [ from, @today ].each do |day|
          todo = @user.daily_todos.for_day(day).find_by!(strategy_goal_id: battle.id)
          todo.update!(completed_at: zone_time(day.year, day.month, day.day, 10))
        end

        assert_equal 2, DaysInARow.count(user: @user)
      end
    end

    test "one missed local day is frozen and streak continues" do
      travel_to zone_time(2026, 8, 6, 12) do
        complete_one_shot!("Two days ago", on: @today - 2)
        complete_one_shot!("Today", on: @today)
        assert_equal 2, DaysInARow.count(user: @user)
      end
    end

    test "two missed local days resets to zero" do
      travel_to zone_time(2026, 8, 6, 12) do
        complete_one_shot!("Three days ago", on: @today - 3)
        assert_equal 0, DaysInARow.count(user: @user)
      end
    end

    test "win yesterday with no win today still counts" do
      travel_to zone_time(2026, 8, 6, 12) do
        complete_one_shot!("Yesterday only", on: @today - 1)
        assert_equal 1, DaysInARow.count(user: @user)
      end
    end

    test "soft freeze with last win two days ago and no win today still counts" do
      travel_to zone_time(2026, 8, 6, 12) do
        complete_one_shot!("Two days ago", on: @today - 2)
        assert_equal 1, DaysInARow.count(user: @user)
      end
    end

    test "local time zone across midnight buckets the win on the local day" do
      la = "America/Los_Angeles"
      @user.notification_preference.update!(time_zone: la)

      # 2026-08-06 01:00 PDT == 2026-08-06 08:00 UTC — still local Aug 6.
      travel_to Time.find_zone!(la).local(2026, 8, 6, 1, 0, 0) do
        complete_one_shot!("Midnight win", on: Date.new(2026, 8, 6), zone: la)
        assert_equal 1, DaysInARow.count(user: @user)
      end
    end

    test "Basics habit log does not count" do
      travel_to zone_time(2026, 8, 6, 12) do
        habit = habits(:one)
        habit.update!(user: @user)
        habit.daily_logs.create!(user: @user, logged_on: @today, amount: 1)

        assert_equal 0, DaysInARow.count(user: @user)
      end
    end

    test "mission completion does not count" do
      travel_to zone_time(2026, 8, 6, 12) do
        seed_climb!(@user, today_mission: "Unused battle")
        missions = @user.missions.for_day(@today)
        assert missions.exists?
        missions.find_each do |mission|
          mission.update!(status: "complete", completed_at: zone_time(2026, 8, 6, 9))
        end

        assert_equal 0, DaysInARow.count(user: @user)
      end
    end

    test "ad-hoc todo without strategy link does not count" do
      travel_to zone_time(2026, 8, 6, 12) do
        @user.daily_todos.create!(
          title: "Personal errand",
          aspect_key: "career",
          scheduled_on: @today,
          position: 0,
          completed_at: zone_time(2026, 8, 6, 10)
        )

        assert_equal 0, DaysInARow.count(user: @user)
      end
    end

    test "calls counts_by_date once" do
      travel_to zone_time(2026, 8, 6, 12) do
        complete_one_shot!("Once", on: @today)
        calls = 0
        original = WinsOnLocalDate.method(:counts_by_date)
        WinsOnLocalDate.define_singleton_method(:counts_by_date) do |**kwargs|
          calls += 1
          original.call(**kwargs)
        end
        begin
          assert_equal 1, DaysInARow.count(user: @user)
          assert_equal 1, calls
        ensure
          WinsOnLocalDate.singleton_class.send(:remove_method, :counts_by_date)
          WinsOnLocalDate.define_singleton_method(:counts_by_date, original)
        end
      end
    end

    private

    def zone_time(year, month, day, hour, zone: @zone)
      Time.find_zone!(zone).local(year, month, day, hour, 0, 0)
    end

    def complete_one_shot!(title, on:, zone: @zone)
      seed_climb!(@user, today_mission: title) unless @user.strategy_goals.battles.exists?
      project = @user.strategy_goals.find_by!(horizon: "project", title: "Auth")
      journey = @user.primary_focused_journey
      battle = project.children.find_by(horizon: "day", title: title)
      battle ||= project.children.create!(
        user: @user,
        life_area: journey.life_area,
        life_journey: journey,
        horizon: "day",
        title: title,
        scheduled_on: on,
        position: project.children.count
      )
      battle.update!(completed_at: zone_time(on.year, on.month, on.day, 9, zone: zone))
      battle
    end
  end
end
