# frozen_string_literal: true

require "test_helper"

module Today
  class StreakMomentTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @user.daily_todos.delete_all
      @user.strategy_goals.delete_all
      @zone = "Europe/Berlin"
      @user.create_notification_preference!(time_zone: @zone) unless @user.notification_preference
      @user.notification_preference.update!(time_zone: @zone)
      reset_streak_state!
      @today = Date.new(2026, 8, 6)
    end

    test "not eligible with fewer than two days in a row" do
      travel_to zone_time(2026, 8, 6, 12) do
        complete_one_shot!("Only today", on: @today)
        assert_not StreakMoment.eligible?(user: @user)
        assert_nil StreakMoment.present_for!(user: @user, goal_title: "Goal")
      end
    end

    test "eligible after two local win days and presents celebrate with offer" do
      travel_to zone_time(2026, 8, 6, 12) do
        complete_one_shot!("Yesterday", on: @today - 1)
        complete_one_shot!("Today", on: @today)

        assert StreakMoment.eligible?(user: @user)
        moment = StreakMoment.present_for!(user: @user, goal_title: "Run a half marathon")
        assert_equal :celebrate, moment.kind
        assert_equal 2, moment.days
        assert_equal 1, moment.from_days
        assert moment.offer_commit
        assert_equal [ 3, 7, 14, 30 ], moment.offered_targets
        assert_equal 7, moment.default_target
        assert_equal "Run a half marathon", moment.goal_title
        assert_equal @today, @user.reload.last_streak_moment_on

        assert_not StreakMoment.eligible?(user: @user)
        assert_nil StreakMoment.present_for!(user: @user, goal_title: "Run a half marathon")
      end
    end

    test "not eligible without a win on local today" do
      travel_to zone_time(2026, 8, 6, 12) do
        complete_one_shot!("Two days ago", on: @today - 2)
        complete_one_shot!("Yesterday", on: @today - 1)

        assert_not StreakMoment.eligible?(user: @user)
      end
    end

    test "quiet clear runs even when days below two gate" do
      travel_to zone_time(2026, 8, 6, 12) do
        @user.update!(
          streak_commitment_target_days: 7,
          streak_commitment_started_on: @today - 5,
          streak_commit_declines: 1
        )

        assert_not StreakMoment.eligible?(user: @user)
        @user.reload
        assert_nil @user.streak_commitment_target_days
        assert_nil @user.streak_commitment_started_on
        assert_equal 1, @user.streak_commit_declines
      end
    end

    test "progress kind when commitment active and days below target" do
      travel_to zone_time(2026, 8, 6, 12) do
        4.times { |i| complete_one_shot!("Day #{i}", on: @today - (3 - i)) }
        @user.update!(
          streak_commitment_target_days: 7,
          streak_commitment_started_on: @today - 3
        )

        moment = StreakMoment.present_for!(user: @user, goal_title: "Goal")
        assert_equal :progress, moment.kind
        assert_equal 4, moment.days
        assert_equal 7, moment.target_days
        assert_equal 57, moment.fill_pct
        assert_not moment.offer_commit
      end
    end

    test "goal kind clears commitment so next day is celebrate" do
      travel_to zone_time(2026, 8, 6, 12) do
        7.times { |i| complete_one_shot!("Day #{i}", on: @today - (6 - i)) }
        @user.update!(
          streak_commitment_target_days: 7,
          streak_commitment_started_on: @today - 6
        )

        moment = StreakMoment.present_for!(user: @user, goal_title: "Goal")
        assert_equal :goal, moment.kind
        assert_equal 7, moment.days
        assert_equal 7, moment.target_days
        assert_nil @user.reload.streak_commitment_target_days
        assert_nil @user.streak_commitment_started_on
      end

      travel_to zone_time(2026, 8, 7, 12) do
        complete_one_shot!("Day 8", on: @today + 1)
        @user.update!(last_streak_moment_on: nil)

        moment = StreakMoment.present_for!(user: @user, goal_title: "Goal")
        assert_equal :celebrate, moment.kind
        assert moment.offer_commit
        assert_not_equal :goal, moment.kind
      end
    end

    test "offer_commit false after two declines" do
      travel_to zone_time(2026, 8, 6, 12) do
        complete_one_shot!("Yesterday", on: @today - 1)
        complete_one_shot!("Today", on: @today)
        @user.update!(streak_commit_declines: 2)

        moment = StreakMoment.present_for!(user: @user, goal_title: "Goal")
        assert_equal :celebrate, moment.kind
        assert_not moment.offer_commit
        assert_empty moment.offered_targets
      end
    end

    test "no offer when streak already at thirty" do
      travel_to zone_time(2026, 8, 6, 12) do
        30.times { |i| complete_one_shot!("Day #{i}", on: @today - (29 - i)) }

        moment = StreakMoment.present_for!(user: @user, goal_title: "Goal")
        assert_equal :celebrate, moment.kind
        assert_not moment.offer_commit
        assert_empty moment.offered_targets
      end
    end

    private

    def reset_streak_state!
      attrs = { last_streak_moment_on: nil }
      if @user.has_attribute?(:streak_commitment_target_days)
        attrs.merge!(
          streak_commitment_target_days: nil,
          streak_commitment_started_on: nil,
          streak_commit_declines: 0
        )
      end
      @user.update!(attrs) if @user.has_attribute?(:last_streak_moment_on)
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
