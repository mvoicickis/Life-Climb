# frozen_string_literal: true

require "test_helper"

module Today
  class StreakCommitmentTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @user.daily_todos.delete_all
      @user.strategy_goals.delete_all
      @zone = "Europe/Berlin"
      @user.create_notification_preference!(time_zone: @zone) unless @user.notification_preference
      @user.notification_preference.update!(time_zone: @zone)
      clear_commitment!
      @today = Date.new(2026, 8, 6)
    end

    test "commit sets target and started_on to local today" do
      travel_to zone_time(2026, 8, 6, 12) do
        complete_one_shot!("Yesterday", on: @today - 1)
        complete_one_shot!("Today", on: @today)

        assert StreakCommitment.for(@user).commit!(days: 7, on: @today)
        @user.reload
        assert_equal 7, @user.streak_commitment_target_days
        assert_equal @today, @user.streak_commitment_started_on
      end
    end

    test "commit rejects target not ahead of current streak" do
      travel_to zone_time(2026, 8, 6, 12) do
        5.times { |i| complete_one_shot!("Day #{i}", on: @today - (4 - i)) }

        refute StreakCommitment.for(@user).commit!(days: 3, on: @today)
        assert_nil @user.reload.streak_commitment_target_days
      end
    end

    test "offered targets are only ahead of days in a row" do
      commitment = StreakCommitment.for(@user)
      assert_equal [ 3, 7, 14, 30 ], commitment.offered_targets(days_in_a_row: 2)
      assert_equal [ 7, 14, 30 ], commitment.offered_targets(days_in_a_row: 3)
      assert_equal [ 14, 30 ], commitment.offered_targets(days_in_a_row: 7)
      assert_equal [], commitment.offered_targets(days_in_a_row: 30)
      assert_equal 7, commitment.default_target([ 3, 7, 14, 30 ])
      assert_equal 14, commitment.default_target([ 14, 30 ])
    end

    test "decline caps at two" do
      commitment = StreakCommitment.for(@user)
      assert commitment.decline!
      assert_equal 1, @user.reload.streak_commit_declines
      assert commitment.decline!
      assert_equal 2, @user.reload.streak_commit_declines
      assert commitment.decline!
      assert_equal 2, @user.reload.streak_commit_declines
    end

    test "quiet clear when streak below two keeps declines" do
      travel_to zone_time(2026, 8, 6, 12) do
        @user.update!(
          streak_commitment_target_days: 7,
          streak_commitment_started_on: @today - 3,
          streak_commit_declines: 1
        )

        StreakCommitment.for(@user).sync!
        @user.reload
        assert_nil @user.streak_commitment_target_days
        assert_nil @user.streak_commitment_started_on
        assert_equal 1, @user.streak_commit_declines
      end
    end

    test "commit started_on uses preference zone local date" do
      travel_to Time.find_zone!("UTC").local(2026, 8, 6, 23, 30, 0) do
        # Berlin is UTC+2 in August → local 2026-08-07
        complete_one_shot!("Yesterday", on: Date.new(2026, 8, 6))
        complete_one_shot!("Today", on: Date.new(2026, 8, 7))

        local = Battles::WinsOnLocalDate.local_today_for(@user)
        assert_equal Date.new(2026, 8, 7), local
        assert StreakCommitment.for(@user).commit!(days: 7, on: local)
        assert_equal Date.new(2026, 8, 7), @user.reload.streak_commitment_started_on
      end
    end

    private

    def clear_commitment!
      return unless @user.has_attribute?(:streak_commitment_target_days)

      @user.update!(
        streak_commitment_target_days: nil,
        streak_commitment_started_on: nil,
        streak_commit_declines: 0,
        last_streak_moment_on: nil
      )
    end

    def zone_time(year, month, day, hour)
      Time.find_zone!(@zone).local(year, month, day, hour, 0, 0)
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
  end
end
