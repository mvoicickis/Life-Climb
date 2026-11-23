# frozen_string_literal: true

require "test_helper"

module Admin
  class BetaTestersRosterTest < ActiveSupport::TestCase
    ANDROID_UA =
      "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) " \
      "Chrome/120.0.0.0 Mobile Safari/537.36"
    IPHONE_UA =
      "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15"

    setup do
      BetaTester.delete_all
      @recent = create_android_user!("recent-win@example.com")
      @never = create_android_user!("never-win@example.com")
      @stale = create_android_user!("stale-win@example.com")
      @iphone = create_android_user!("iphone-only@example.com", user_agent: IPHONE_UA)
    end

    test "not_testers lists only android users not on the tester list" do
      plant_one_shot_win!(@recent, completed_at: 2.days.ago)
      plant_one_shot_win!(@stale, completed_at: 20.days.ago)
      BetaTester.create!(email: @stale.email_address, added_at: Time.current, user: @stale)

      roster = BetaTestersRoster.call
      emails = roster[:not_testers].map { |row| row.user.email_address }

      assert_includes emails, "recent-win@example.com"
      assert_includes emails, "never-win@example.com"
      assert_not_includes emails, "stale-win@example.com"
      assert_not_includes emails, "iphone-only@example.com"
    end

    test "not_testers sort by tier then recent activity" do
      travel_to Time.zone.parse("2026-11-23 12:00:00") do
        plant_one_shot_win!(@recent, completed_at: 1.day.ago)
        plant_one_shot_win!(@stale, completed_at: 10.days.ago)

        roster = BetaTestersRoster.call
        tiers = roster[:not_testers].map(&:tier)

        assert_equal [
          BetaTestersRoster::TIER_RECENT_WIN,
          BetaTestersRoster::TIER_NEVER_WON,
          BetaTestersRoster::TIER_OTHER
        ], tiers
      end
    end

    test "beta list match is case insensitive" do
      BetaTester.create!(email: "RECENT-WIN@example.com", added_at: Time.current, user: @recent)

      roster = BetaTestersRoster.call
      emails = roster[:not_testers].map { |row| row.user.email_address }

      assert_not_includes emails, "recent-win@example.com"
    end

    test "no_account lists tester emails without a user" do
      BetaTester.create!(email: "ghost@example.com", added_at: Time.current, user: nil)
      BetaTester.create!(email: @recent.email_address, added_at: Time.current, user: @recent)

      roster = BetaTestersRoster.call
      emails = roster[:no_account].map { |row| row.beta_tester.email }

      assert_equal [ "ghost@example.com" ], emails
    end

    private

    def create_android_user!(email, user_agent: ANDROID_UA)
      user = User.create!(
        email_address: email,
        name: "Tester",
        password: "password12345",
        onboarding_completed_at: Time.current
      )
      user.sessions.create!(user_agent: user_agent, ip_address: "127.0.0.1")
      user
    end

    def plant_one_shot_win!(user, completed_at:)
      seed_climb!(user, today_mission: "Roster win #{SecureRandom.hex(3)}") unless user.strategy_goals.battles.exists?
      battle = user.strategy_goals.battles.order(:id).last
      battle.update!(completed_at: completed_at, repeat: nil)
    end
  end
end
