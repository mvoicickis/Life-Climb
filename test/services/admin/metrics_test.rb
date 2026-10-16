# frozen_string_literal: true

require "test_helper"

module Admin
  class MetricsTest < ActiveSupport::TestCase
    ZONE = "Europe/Berlin"

    setup do
      @opened_with_win = users(:one)
      @opened_no_win = users(:two)
      @admin = users(:admin)
      @yesterday_user = User.create!(
        name: "Yesterday",
        email_address: "opened-yesterday-#{SecureRandom.hex(4)}@example.com",
        password: "password12345",
        password_confirmation: "password12345",
        onboarding_completed_at: Time.current
      )

      [ @opened_with_win, @opened_no_win, @admin, @yesterday_user ].each do |user|
        user.notification_preference&.destroy
        user.create_notification_preference!(time_zone: ZONE)
      end
    end

    test "opened today and climbed today counts use local day and exclude privileged users" do
      travel_to berlin_time(2026, 10, 16, 12, 0) do
        today = Date.new(2026, 10, 16)
        yesterday = today - 1

        @opened_with_win.update!(last_opened_on: today)
        @opened_no_win.update!(last_opened_on: today)
        @admin.update!(last_opened_on: today)
        @yesterday_user.update!(last_opened_on: yesterday)

        seed_daily_win!(@opened_with_win, today)

        cards = Metrics.call[:cards]

        assert_equal 2, cards[:opened_today]
        assert_equal 1, cards[:climbed_today]
      end
    end

    private

    def berlin_time(year, month, day, hour, minute)
      Time.find_zone!(ZONE).local(year, month, day, hour, minute, 0)
    end

    def seed_daily_win!(user, date)
      seed_climb!(user, today_mission: "Metrics daily win")
      battle = user.strategy_goals.find_by!(horizon: "day", title: "Metrics daily win")
      battle.update!(repeat: "daily")
      Strategy::CascadeToDaily.call(user: user, life_area: battle.life_area, from: date, to: date)
      todo = user.daily_todos.for_day(date).find_by!(strategy_goal_id: battle.id)
      todo.update!(completed_at: Time.find_zone!(ZONE).local(date.year, date.month, date.day, 10, 0, 0))
    end
  end
end
