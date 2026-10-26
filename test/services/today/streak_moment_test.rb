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
      @user.update!(last_streak_moment_on: nil) if @user.has_attribute?(:last_streak_moment_on)
      @today = Date.new(2026, 8, 6)
    end

    test "not eligible with fewer than two days in a row" do
      travel_to zone_time(2026, 8, 6, 12) do
        complete_one_shot!("Only today", on: @today)
        assert_not StreakMoment.eligible?(user: @user)
        assert_nil StreakMoment.present_for!(user: @user, goal_title: "Goal")
      end
    end

    test "eligible after two local win days and presents once" do
      travel_to zone_time(2026, 8, 6, 12) do
        complete_one_shot!("Yesterday", on: @today - 1)
        complete_one_shot!("Today", on: @today)

        assert StreakMoment.eligible?(user: @user)
        moment = StreakMoment.present_for!(user: @user, goal_title: "Run a half marathon")
        assert_equal 2, moment.days
        assert_equal 1, moment.from_days
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

    private

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
