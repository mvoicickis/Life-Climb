# frozen_string_literal: true

require "test_helper"

module ClimbTogether
  class InvitesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @inviter = users(:one)
      @invitee = users(:two)
      @other = users(:admin)
      ClimbPartnership.delete_all
      HighFive.delete_all
      seed_climb!(@inviter)
      seed_climb!(@invitee, area_key: "self", today_mission: "Invitee battle")
      @invite = Invite.call(user: @inviter)
    end

    test "show open invite when logged out" do
      get climb_invite_path(@invite.token)

      assert_response :success
      assert_match(/#{Regexp.escape(@inviter.display_name)} wants to climb with you/i, response.body)
      assert_select "form[action=?]", accept_climb_invite_path(@invite.token)
      assert_select "a[href=?]", root_path, text: I18n.t("climb_together.accept.not_now")
    end

    test "show open invite when logged in as invitee" do
      sign_in_as @invitee

      get climb_invite_path(@invite.token)

      assert_response :success
      assert_match(/#{Regexp.escape(@inviter.display_name)} wants to climb with you/i, response.body)
      assert_select "a[href=?]", dashboard_path, text: I18n.t("climb_together.accept.not_now")
    end

    test "show closed card for invalid token" do
      get climb_invite_path("not-a-real-token")

      assert_response :success
      assert_match(/isn’t open anymore/i, response.body)
      assert_select "a[href=?]", root_path, text: I18n.t("climb_together.closed.cta")
    end

    test "show closed card for own invite" do
      sign_in_as @inviter

      get climb_invite_path(@invite.token)

      assert_response :success
      assert_match(/isn’t open anymore/i, response.body)
    end

    test "show closed card when already partnered" do
      Accept.call(user: @invitee, token: @invite.token)
      other_invite = Invite.call(user: @other)
      sign_in_as @invitee

      get climb_invite_path(other_invite.token)

      assert_response :success
      assert_match(/isn’t open anymore/i, response.body)
    end

    test "accept happy path partners and flashes on Today" do
      sign_in_as @invitee

      post accept_climb_invite_path(@invite.token)

      assert_redirected_to dashboard_path
      follow_redirect!
      assert_match(/climbing with #{Regexp.escape(@inviter.display_name)}/i, response.body)
      assert_equal @inviter, PartnerFor.call(user: @invitee)
      assert_nil session[ClimbTogether::INVITE_TOKEN_SESSION_KEY]
    end

    test "logged out accept stashes token, signup login returns to invite" do
      post accept_climb_invite_path(@invite.token)

      assert_redirected_to new_registration_path
      assert_equal @invite.token, session[ClimbTogether::INVITE_TOKEN_SESSION_KEY]
      assert_equal climb_invite_path(@invite.token), session[:return_to_after_authenticating]

      get new_session_path
      post session_path, params: {
        email_address: @invitee.email_address,
        password: "password12345"
      }

      assert_redirected_to climb_invite_path(@invite.token)
      follow_redirect!
      assert_match(/#{Regexp.escape(@inviter.display_name)} wants to climb with you/i, response.body)
    end

    test "new signup with invite token lands on accept after onboarding" do
      post accept_climb_invite_path(@invite.token)
      assert_redirected_to new_registration_path

      email = "climb-invite-new-#{SecureRandom.hex(4)}@example.com"
      post registration_url, params: {
        user: {
          name: "New Climber",
          email_address: email,
          password: "password12345"
        }
      }
      assert_redirected_to v2_onboarding_path(step: "intro_big_goals")
      assert_equal @invite.token, session[ClimbTogether::INVITE_TOKEN_SESSION_KEY]

      patch v2_onboarding_url(step: "goal"), params: { onboarding: { goal: "Ship Life Climb" } }
      patch v2_onboarding_url(step: "camps"), params: {
        onboarding: { camp_titles: [ "First camp", "Second camp" ] }
      }
      patch v2_onboarding_url(step: "climb")
      patch v2_onboarding_url(step: "battles"), params: {
        onboarding: { battle_titles: [ "First battle" ] }
      }
      patch v2_onboarding_url(step: "celebrate")

      assert_redirected_to climb_invite_path(@invite.token)
      follow_redirect!
      assert_match(/#{Regexp.escape(@inviter.display_name)} wants to climb with you/i, response.body)
    end

    test "google new account keeps climb invite token through onboarding" do
      OmniAuth.config.test_mode = true
      post accept_climb_invite_path(@invite.token)
      assert_equal @invite.token, session[ClimbTogether::INVITE_TOKEN_SESSION_KEY]

      email = "google-climb-#{SecureRandom.hex(4)}@example.com"
      OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
        provider: "google_oauth2",
        uid: "sub-climb-#{SecureRandom.hex(4)}",
        info: { email: email, name: "Google Climber", email_verified: true },
        extra: {
          raw_info: {
            sub: "sub-climb-#{SecureRandom.hex(4)}",
            email: email,
            name: "Google Climber",
            email_verified: true
          }
        }
      )

      get "/auth/google_oauth2/callback"
      assert_redirected_to v2_onboarding_path(step: "intro_big_goals")
      assert_equal @invite.token, session[ClimbTogether::INVITE_TOKEN_SESSION_KEY]

      patch v2_onboarding_url(step: "goal"), params: { onboarding: { goal: "Google mountain" } }
      patch v2_onboarding_url(step: "camps"), params: {
        onboarding: { camp_titles: [ "Camp one", "Camp two" ] }
      }
      patch v2_onboarding_url(step: "climb")
      patch v2_onboarding_url(step: "battles"), params: {
        onboarding: { battle_titles: [ "First battle" ] }
      }
      patch v2_onboarding_url(step: "celebrate")

      assert_redirected_to climb_invite_path(@invite.token)
    ensure
      OmniAuth.config.test_mode = false
      OmniAuth.config.mock_auth[:google_oauth2] = nil
    end

    test "normal signup and onboarding without token is unchanged" do
      email = "normal-signup-#{SecureRandom.hex(4)}@example.com"
      post registration_url, params: {
        user: {
          name: "Normal",
          email_address: email,
          password: "password12345"
        }
      }
      assert_redirected_to v2_onboarding_path(step: "intro_big_goals")
      assert_nil session[ClimbTogether::INVITE_TOKEN_SESSION_KEY]

      patch v2_onboarding_url(step: "goal"), params: { onboarding: { goal: "Normal mountain" } }
      patch v2_onboarding_url(step: "camps"), params: {
        onboarding: { camp_titles: [ "Camp A", "Camp B" ] }
      }
      patch v2_onboarding_url(step: "climb")
      patch v2_onboarding_url(step: "battles"), params: {
        onboarding: { battle_titles: [ "Camp A step" ] }
      }
      patch v2_onboarding_url(step: "celebrate")

      user = User.find_by!(email_address: email)
      assert_redirected_to dashboard_path
    end
  end
end
