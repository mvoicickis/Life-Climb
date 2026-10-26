# frozen_string_literal: true

require "test_helper"

module Notifications
  class NudgeBodyTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @user.daily_todos.delete_all
      @user.strategy_goals.delete_all
      @zone = "Europe/Berlin"
      @user.create_notification_preference!(time_zone: @zone) unless @user.notification_preference
      @user.notification_preference.update!(time_zone: @zone)
      @user.update!(
        streak_commitment_target_days: nil,
        streak_commitment_started_on: nil,
        streak_commit_declines: 0
      ) if @user.has_attribute?(:streak_commitment_target_days)
      @today = Date.new(2026, 8, 6)
      @fallback = "One small step before bed."
    end

    test "no commitment keeps Today battle body" do
      travel_to zone_time(2026, 8, 6, 12) do
        seed_open_battle!("Call my mum", on: @today)

        body = NudgeBody.build(user: @user, date: @today, fallback: @fallback)
        assert_equal "Today: Call my mum", body
      end
    end

    test "commitment not won today uses DaysInARow plus one" do
      travel_to zone_time(2026, 8, 6, 12) do
        complete_one_shot!("Two days ago", on: @today - 2)
        complete_one_shot!("Yesterday", on: @today - 1)
        @user.update!(streak_commitment_target_days: 7, streak_commitment_started_on: @today - 2)
        seed_open_battle!("Call my mum", on: @today)

        assert_equal 2, Battles::DaysInARow.count(user: @user)
        refute BattleWinsOnLocalDate.any?(user: @user, date: @today, time_zone: @zone)

        body = NudgeBody.build(user: @user, date: @today, fallback: @fallback)
        assert_equal "Day 3 of 7: Call my mum", body
      end
    end

    test "commitment won today uses DaysInARow" do
      travel_to zone_time(2026, 8, 6, 12) do
        complete_one_shot!("Yesterday", on: @today - 1)
        complete_one_shot!("Today win", on: @today)
        @user.update!(streak_commitment_target_days: 7, streak_commitment_started_on: @today - 1)
        seed_open_battle!("Call my mum", on: @today)

        assert_equal 2, Battles::DaysInARow.count(user: @user)
        assert BattleWinsOnLocalDate.any?(user: @user, date: @today, time_zone: @zone)

        body = NudgeBody.build(user: @user, date: @today, fallback: @fallback)
        assert_equal "Day 2 of 7: Call my mum", body
      end
    end

    test "commitment with no open battle uses fallback as rest" do
      travel_to zone_time(2026, 8, 6, 12) do
        complete_one_shot!("Two days ago", on: @today - 2)
        complete_one_shot!("Yesterday", on: @today - 1)
        @user.update!(streak_commitment_target_days: 7, streak_commitment_started_on: @today - 2)

        body = NudgeBody.build(user: @user, date: @today, fallback: @fallback)
        assert_equal "Day 3 of 7: One small step before bed.", body
      end
    end

    test "n caps at target when streak would exceed" do
      travel_to zone_time(2026, 8, 6, 12) do
        7.times { |i| complete_one_shot!("Day #{i}", on: @today - (7 - i)) }
        @user.update!(streak_commitment_target_days: 7, streak_commitment_started_on: @today - 7)
        seed_open_battle!("Call my mum", on: @today)

        assert_equal 7, Battles::DaysInARow.count(user: @user)
        refute BattleWinsOnLocalDate.any?(user: @user, date: @today, time_zone: @zone)

        body = NudgeBody.build(user: @user, date: @today, fallback: @fallback)
        assert_equal "Day 7 of 7: Call my mum", body
      end
    end

    test "broken commitment leaves body unchanged and does not write" do
      travel_to zone_time(2026, 8, 6, 12) do
        seed_open_battle!("Call my mum", on: @today)
        @user.update!(
          streak_commitment_target_days: 7,
          streak_commitment_started_on: @today - 10,
          streak_commit_declines: 1
        )
        before = commitment_snapshot

        body = NudgeBody.build(user: @user, date: @today, fallback: @fallback)
        assert_equal "Today: Call my mum", body
        assert_equal before, commitment_snapshot
        assert_equal 7, @user.reload.streak_commitment_target_days
      end
    end

    test "peek uses preference zone local date across midnight" do
      travel_to Time.find_zone!("UTC").local(2026, 8, 6, 22, 30, 0) do
        # Berlin UTC+2 in August → local 2026-08-07
        local = Date.new(2026, 8, 7)
        complete_one_shot!("Two days ago", on: local - 2)
        complete_one_shot!("Yesterday", on: local - 1)
        @user.update!(streak_commitment_target_days: 7, streak_commitment_started_on: local - 2)
        seed_open_battle!("Call my mum", on: local)

        assert_equal local, Battles::WinsOnLocalDate.local_today_for(@user)
        body = NudgeBody.build(user: @user, date: local, fallback: @fallback)
        assert_equal "Day 3 of 7: Call my mum", body
      end
    end

    private

    def zone_time(year, month, day, hour)
      Time.find_zone!(@zone).local(year, month, day, hour, 0, 0)
    end

    def commitment_snapshot
      @user.reload
      {
        target: @user.streak_commitment_target_days,
        started_on: @user.streak_commitment_started_on,
        declines: @user.streak_commit_declines
      }
    end

    def complete_one_shot!(title, on:)
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
      battle.update!(completed_at: zone_time(on.year, on.month, on.day, 9))
      battle
    end

    def seed_open_battle!(title, on:)
      seed_climb!(@user, today_mission: "Warm up") unless @user.strategy_goals.battles.exists?
      project = @user.strategy_goals.find_by!(horizon: "project", title: "Auth")
      journey = @user.primary_focused_journey
      battle = project.children.create!(
        user: @user,
        life_area: journey.life_area,
        life_journey: journey,
        horizon: "day",
        title: "Open #{title}",
        scheduled_on: on,
        position: project.children.count
      )
      @user.daily_todos.where(scheduled_on: on).delete_all
      @user.daily_todos.create!(
        title: title,
        aspect_key: "career",
        scheduled_on: on,
        position: 0,
        lp_reward: 10,
        strategy_goal_id: battle.id,
        tag: "strategy"
      )
    end
  end
end
