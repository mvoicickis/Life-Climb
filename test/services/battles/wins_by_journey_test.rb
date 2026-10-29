# frozen_string_literal: true

require "test_helper"

module Battles
  class WinsByJourneyTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @user.daily_todos.delete_all
      @zone = "Europe/Berlin"
      @user.create_notification_preference!(time_zone: @zone) unless @user.notification_preference
      @user.notification_preference.update!(time_zone: @zone)
      @today = Date.new(2026, 8, 6)
      # Keep created_at before travel_to dates so all-time windows include earlier wins.
      @user.update_column(:created_at, Time.find_zone!(@zone).local(2026, 1, 1, 12, 0, 0))
      allow_extra_climbs!(@user)
    end

    test "counts one-shot and recurring wins per journey including earlier days" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
        journey_a = seed_climb!(@user, area_key: "career", title: "Career climb", today_mission: "Ship auth")
        journey_b = seed_second_journey!(title: "Health climb", area_key: "self", battle_title: "Sleep by 11")

        one_shot = @user.strategy_goals.find_by!(horizon: "day", title: "Ship auth", life_journey_id: journey_a.id)
        one_shot.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 5, 9, 0, 0))

        daily = @user.strategy_goals.find_by!(horizon: "day", title: "Sleep by 11", life_journey_id: journey_b.id)
        daily.update!(repeat: "daily")
        complete_recurring_win!(battle: daily, on: @today - 1, aspect_key: "self")
        complete_recurring_win!(battle: daily, on: @today, aspect_key: "self")

        counts = WinsByJourney.call(user: @user)
        assert_equal 1, counts[journey_a.id]
        assert_equal 2, counts[journey_b.id]
        refute counts.key?(nil)
      end
    end

    test "Basics, ad-hoc todos and missions do not count" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
        seed_climb!(@user, today_mission: "Unused battle")

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

        assert_equal({}, WinsByJourney.call(user: @user))
      end
    end

    test "another user wins never appear" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
        other = users(:two)
        other.create_notification_preference!(time_zone: @zone) unless other.notification_preference
        other.notification_preference.update!(time_zone: @zone)
        allow_extra_climbs!(other)

        journey = seed_climb!(other, today_mission: "Other win")
        battle = other.strategy_goals.find_by!(horizon: "day", title: "Other win")
        battle.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 6, 9, 0, 0))

        seed_climb!(@user, today_mission: "My unused")
        assert_equal({}, WinsByJourney.call(user: @user))
        assert_equal({ journey.id => 1 }, WinsByJourney.call(user: other))
      end
    end

    test "sum of journeys matches Stats::BattleWins all-time total" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
        journey_a = seed_climb!(@user, area_key: "career", title: "Career climb", today_mission: "Ship auth")
        journey_b = seed_second_journey!(title: "Health climb", area_key: "self", battle_title: "Sleep by 11")

        one_shot = @user.strategy_goals.find_by!(horizon: "day", title: "Ship auth", life_journey_id: journey_a.id)
        one_shot.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 4, 9, 0, 0))

        daily = @user.strategy_goals.find_by!(horizon: "day", title: "Sleep by 11", life_journey_id: journey_b.id)
        daily.update!(repeat: "daily")
        complete_recurring_win!(battle: daily, on: @today, aspect_key: "self")

        by_journey = WinsByJourney.call(user: @user)
        all_time = Stats::BattleWins.call(user: @user).all_time_total
        assert_equal all_time, by_journey.values.sum
        assert_equal 2, all_time
      end
    end

    test "query count stays flat from one journey to five" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
        journeys = []
        journeys << seed_climb!(@user, area_key: "career", title: "Climb 1", today_mission: "Battle 1")
        battle = @user.strategy_goals.find_by!(horizon: "day", title: "Battle 1")
        battle.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 6, 9, 0, 0))

        WinsOnLocalDate.time_zone_for(@user)
        WinsOnLocalDate.local_today_for(@user)
        service_one = WinsByJourney.new(user: @user)
        one_queries = count_sql_queries { service_one.call }

        4.times do |i|
          n = i + 2
          journey = seed_second_journey!(
            title: "Climb #{n}",
            area_key: %w[self purpose money learning][i],
            battle_title: "Battle #{n}"
          )
          journeys << journey
          b = @user.strategy_goals.find_by!(horizon: "day", title: "Battle #{n}", life_journey_id: journey.id)
          b.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 6, 9, i, 0))
        end

        WinsOnLocalDate.time_zone_for(@user)
        WinsOnLocalDate.local_today_for(@user)
        service_five = WinsByJourney.new(user: @user)
        five_queries = count_sql_queries { service_five.call }

        assert_equal 5, WinsByJourney.call(user: @user).size
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
