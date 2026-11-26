# frozen_string_literal: true

require "test_helper"

module Admin
  class ReferralsRosterTest < ActiveSupport::TestCase
    test "summary counts referred accounts beta signups and first wins" do
      referrer = users(:one)
      invitee = User.create!(
        name: "Summary Invite",
        email_address: "summary-invite@example.com",
        password: "password12345",
        referred_by_id: referrer.id
      )
      seed_climb!(invitee, today_mission: "Win for referrals roster")
      invitee.strategy_goals.battles.order(:id).last.update!(completed_at: Time.current, repeat: nil)
      BetaSignup.create!(email: "beta-only@example.com", source_path: "/", referred_by_id: referrer.id)

      result = ReferralsRoster.call

      assert_equal 1, result[:summary].referrers
      assert_equal 1, result[:summary].accounts
      assert_equal 1, result[:summary].beta_emails
      assert_equal 1, result[:summary].first_wins
    end

    test "beta row omitted when email already has account" do
      referrer = users(:two)
      email = "both@example.com"
      User.create!(
        name: "Has Account",
        email_address: email,
        password: "password12345",
        referred_by_id: referrer.id
      )
      BetaSignup.create!(email: email, source_path: "/", referred_by_id: referrer.id)

      card = ReferralsRoster.call[:cards].sole

      assert_equal 1, card.accounts_count
      assert_equal 0, card.beta_count
    end
  end
end
