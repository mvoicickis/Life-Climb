# frozen_string_literal: true

require "test_helper"

module Battles
  class WinsByJourneyAndDayTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @user.daily_todos.delete_all
      @zone = "America/Los_Angeles"
      @user.create_notification_preference!(time_zone: @zone) unless @user.notification_preference
      @user.notification_preference.update!(time_zone: @zone)
      @today = Date.new(2026, 8, 6)
      @user.update_column(:created_at, Time.find_zone!(@zone).local(2026, 1, 1, 12, 0, 0))
      allow_extra_climbs!(@user)
    end

    test "one-shot win near local midnight lands on the local day" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
        journey = seed_second_journey!(title: "Night climb", area_key: "career", battle_title: "Late win")
        battle = @user.strategy_goals.find_by!(horizon: "day", title: "Late win", life_journey_id: journey.id)
        # 23:30 Pacific on Aug 5 — still Aug 5 locally, already Aug 6 UTC.
        battle.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 5, 23, 30, 0))
        assert_equal Date.new(2026, 8, 6), battle.completed_at.utc.to_date

        counts = WinsByJourneyAndDay.call(user: @user, days: 7)
        assert_equal 1, counts.dig(journey.id, Date.new(2026, 8, 5))
        assert_equal 0, counts.dig(journey.id, Date.new(2026, 8, 6)).to_i
      end
    end

    test "recurring win uses scheduled_on local day" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
        journey = seed_second_journey!(title: "Daily climb", area_key: "self", battle_title: "Sleep by 11")
        daily = @user.strategy_goals.find_by!(horizon: "day", title: "Sleep by 11", life_journey_id: journey.id)
        daily.update!(repeat: "daily")
        complete_recurring_win!(battle: daily, on: @today - 2, aspect_key: "self")
        complete_recurring_win!(battle: daily, on: @today, aspect_key: "self")

        counts = WinsByJourneyAndDay.call(user: @user, days: 7)
        assert_equal 1, counts.dig(journey.id, @today - 2)
        assert_equal 1, counts.dig(journey.id, @today)
        assert_equal 0, counts.dig(journey.id, @today - 1).to_i
      end
    end

    test "Basics, ad-hoc todos and missions do not count" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
        seed_second_journey!(title: "Quiet", area_key: "career", battle_title: "Unused")

        habit = habits(:one)
        habit.update!(user: @user)
        habit.daily_logs.create!(user: @user, logged_on: @today, amount: 1)

        @user.daily_todos.create!(
          title: "Personal errand",
          aspect_key: "career",
          scheduled_on: @today,
          position: 99,
          completed_at: Time.find_zone!(@zone).local(2026, 8, 6, 10, 0, 0)
        )

        @user.missions.for_day(@today).find_each do |mission|
          mission.update!(status: "complete", completed_at: Time.find_zone!(@zone).local(2026, 8, 6, 9, 0, 0))
        end

        assert_equal({}, WinsByJourneyAndDay.call(user: @user, days: 7))
      end
    end

    test "query count stays at two with more journeys" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
        journey = seed_second_journey!(title: "Climb 1", area_key: "career", battle_title: "Battle 1")
        battle = @user.strategy_goals.find_by!(horizon: "day", title: "Battle 1", life_journey_id: journey.id)
        battle.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 6, 9, 0, 0))

        WinsOnLocalDate.time_zone_for(@user)
        WinsOnLocalDate.local_today_for(@user)
        one_queries = count_sql_queries { WinsByJourneyAndDay.new(user: @user, days: 7).call }

        4.times do |i|
          n = i + 2
          area = %w[self purpose money learning][i]
          j = seed_second_journey!(title: "Climb #{n}", area_key: area, battle_title: "Battle #{n}")
          b = @user.strategy_goals.find_by!(horizon: "day", title: "Battle #{n}", life_journey_id: j.id)
          b.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 6, 9, i, 0))
        end

        WinsOnLocalDate.time_zone_for(@user)
        WinsOnLocalDate.local_today_for(@user)
        five_queries = count_sql_queries { WinsByJourneyAndDay.new(user: @user, days: 7).call }

        assert_equal 2, one_queries
        assert_equal one_queries, five_queries,
                     "expected flat queries (1-journey=#{one_queries}, 5-journey=#{five_queries})"
      end
    end

    private

    def seed_second_journey!(title:, area_key:, battle_title:)
      LifeAreas::Select.call(user: @user, keys: [ area_key ])
      area = @user.life_areas.v2_selected.find_by!(key: area_key)
      journey = Journeys::Create.call(
        user: @user,
        life_area: area,
        title: title,
        ideal_scene: "Ideal #{title}",
        current_reality: "Present #{title}",
        next_win: "Next #{title}",
        closer_percent: 20
      )
      goal = @user.strategy_goals.create!(
        user: @user,
        life_area: area,
        life_journey: journey,
        horizon: "goal",
        title: title,
        position: 0
      )
      plan = goal.children.create!(
        user: @user, life_area: area, life_journey: journey,
        horizon: "plan", title: "Plan #{title}", position: 0
      )
      project = plan.children.create!(
        user: @user, life_area: area, life_journey: journey,
        horizon: "project", title: "Camp #{title}", position: 0
      )
      project.children.create!(
        user: @user, life_area: area, life_journey: journey,
        horizon: "day", title: battle_title, scheduled_on: @today, position: 0
      )
      journey
    end

    def complete_recurring_win!(battle:, on:, aspect_key:)
      zone = Time.find_zone!(@zone)
      @user.daily_todos.create!(
        title: battle.title,
        aspect_key: aspect_key,
        scheduled_on: on,
        position: @user.daily_todos.for_day(on).count,
        strategy_goal: battle,
        tag: "strategy",
        completed_at: zone.local(on.year, on.month, on.day, 10, 0, 0)
      )
    end

    def count_sql_queries
      queries = 0
      callback = lambda do |_name, _start, _finish, _id, payload|
        next if payload[:cached]
        next if payload[:name] == "SCHEMA" || payload[:name] == "TRANSACTION"

        queries += 1 if payload[:sql].present?
      end

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        yield
      end
      queries
    end
  end
end
