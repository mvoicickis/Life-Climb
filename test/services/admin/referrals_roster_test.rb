# frozen_string_literal: true

require "test_helper"

module Admin
  class ReferralsRosterTest < ActiveSupport::TestCase
    setup do
      User.where.not(referred_by_id: nil).update_all(referred_by_id: nil)
      BetaSignup.delete_all
    end

    test "summary counts referred accounts beta signups and first wins" do
      referrer = users(:one)
      invitee = User.create!(
        name: "Summary Invite",
        email_address: "summary-invite@example.com",
        password: "password12345",
        referred_by_id: referrer.id
      )
      Onboarding::Bootstrap.call(
        user: invitee,
        goal_title: "Test goal",
        camp_titles: [ "Camp" ],
        first_camp_reveal_status: "done"
      )
      invitee.strategy_goals.battles.first.update!(completed_at: Time.current)
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
