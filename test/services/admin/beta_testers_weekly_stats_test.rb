# frozen_string_literal: true

require "test_helper"

module Admin
  class BetaTestersWeeklyStatsTest < ActiveSupport::TestCase
    ZONE = BetaTestersWeeklyStats::DAY_ZONE

    setup do
      BetaTester.delete_all
      @user = users(:one)
      @other = users(:two)
    end

    test "invites are counted in the matching Berlin week" do
      travel_to berlin_at(2026, 11, 19, 12) do
        @user.update!(beta_invited_at: berlin_at(2026, 11, 18, 10))
        @other.update!(beta_invited_at: berlin_at(2026, 11, 10, 10))

        stats = BetaTestersWeeklyStats.call(berlin_today: Date.new(2026, 11, 19))

        assert_equal 1, stats[:karen].this_week.invites_sent
        assert_equal 1, stats[:karen].last_week.invites_sent
      end
    end

    test "became testers only when added after invite in the same week window" do
      travel_to berlin_at(2026, 11, 19, 12) do
        invited_at = berlin_at(2026, 11, 17, 9)
        @user.update!(beta_invited_at: invited_at)

        BetaTester.create!(
          email: @user.email_address,
          added_at: berlin_at(2026, 11, 18, 11),
          user: @user
        )
        BetaTester.create!(
          email: "early@example.com",
          added_at: berlin_at(2026, 11, 16, 11),
          user: nil
        )

        stats = BetaTestersWeeklyStats.call(berlin_today: Date.new(2026, 11, 19))

        assert_equal 1, stats[:karen].this_week.became_testers
      end
    end

    test "daily climber this week needs a win every day so far" do
      travel_to berlin_at(2026, 11, 19, 12) do
        today = Date.new(2026, 11, 19)
        week_monday = today.beginning_of_week(:monday)
        BetaTester.create!(email: @user.email_address, added_at: Time.current, user: @user)
        BetaTester.create!(email: @other.email_address, added_at: Time.current, user: @other)

        (week_monday..(today - 1.day)).each do |day|
          plant_one_shot_win!(@user, at: berlin_at(day.year, day.month, day.day, 10), title: "Win #{day} a")
        end
        (week_monday..today).each do |day|
          plant_one_shot_win!(@other, at: berlin_at(day.year, day.month, day.day, 10), title: "Win #{day} b")
        end

        stats = BetaTestersWeeklyStats.call(berlin_today: today)

        assert_equal 1, stats[:mareks].this_week.daily_climbers
      end
    end

    test "daily climber last week needs wins on all seven days" do
      travel_to berlin_at(2026, 11, 19, 12) do
        today = Date.new(2026, 11, 19)
        last_monday = today.beginning_of_week(:monday) - 7.days
        BetaTester.create!(email: @user.email_address, added_at: Time.current, user: @user)
        BetaTester.create!(email: @other.email_address, added_at: Time.current, user: @other)

        (last_monday..(last_monday + 5.days)).each do |day|
          plant_one_shot_win!(@user, at: berlin_at(day.year, day.month, day.day, 10), title: "Last #{day} a")
        end
        (last_monday..(last_monday + 6.days)).each do |day|
          plant_one_shot_win!(@other, at: berlin_at(day.year, day.month, day.day, 10), title: "Last #{day} b")
        end

        stats = BetaTestersWeeklyStats.call(berlin_today: today)

        assert_equal 1, stats[:mareks].last_week.daily_climbers
      end
    end

    private

    def berlin_at(year, month, day, hour = 0, min = 0)
      Time.find_zone!(ZONE).local(year, month, day, hour, min, 0)
    end

    def plant_one_shot_win!(user, at:, title:)
      journey = user.primary_focused_journey || seed_climb!(user, today_mission: title)
      camp = user.strategy_goals.where(horizon: "project", life_journey_id: journey.id).order(:id).last
      battle = user.strategy_goals.battles.find_by(title: title)
      battle ||= add_todays_battle!(user: user, project: camp, journey: journey, title: title)
      battle.update!(completed_at: at, repeat: nil, scheduled_on: at.in_time_zone(ZONE).to_date)
    end
  end
end
