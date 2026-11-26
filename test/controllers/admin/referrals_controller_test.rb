# frozen_string_literal: true

require "test_helper"

module Admin
  class ReferralsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:admin)
      @user = users(:one)
    end

    test "non admin is redirected with access denied" do
      sign_in_as @user
      get admin_referrals_path

      assert_redirected_to dashboard_path
      follow_redirect!
      assert_match(/Access denied/i, flash[:alert].to_s + response.body)
    end

    test "guest is sent to sign in" do
      get admin_referrals_path
      assert_redirected_to new_session_path
    end

    test "empty state shows admin share link" do
      sign_in_as @admin
      url = admin_referral_link_for(@admin)
      empty = {
        summary: ReferralsRoster::Summary.new(0, 0, 0, 0),
        cards: []
      }

      ReferralsRoster.stub(:call, empty) do
        get admin_referrals_path
      end

      assert_response :success
      assert_includes response.body, I18n.t("admin.referrals.empty")
      assert_includes response.body, url
    end

    test "admin sees referrer card with account and beta rows" do
      sign_in_as @admin
      referrer = users(:two)
      invitee = User.create!(
        name: "Referred Climber",
        email_address: "invited-by-two@example.com",
        password: "password12345",
        referred_by_id: referrer.id
      )
      Onboarding::Bootstrap.call(
        user: invitee,
        goal_title: "Test goal",
        camp_titles: [ "Camp" ],
        first_camp_reveal_status: "done"
      )
      win_at = Time.zone.local(2026, 11, 20, 10, 0, 0)
      battle = invitee.strategy_goals.battles.first
      battle.update!(completed_at: win_at)
      BetaSignup.create!(
        email: "waitlist@example.com",
        source_path: "/",
        referred_by_id: referrer.id
      )

      get admin_referrals_path

      assert_response :success
      assert_includes response.body, referrer.email_address
      assert_includes response.body, invitee.email_address
      assert_includes response.body, "waitlist@example.com"
      assert_includes response.body, I18n.l(win_at.to_date, format: :long)
      assert_includes response.body, CanonicalHost.base_url
      assert_includes response.body, referrer.referral_code
    end

    private

    def admin_referral_link_for(user)
      code = ERB::Util.url_encode(user.referral_code.to_s)
      "#{CanonicalHost.base_url}/?r=#{code}"
    end
  end
end
