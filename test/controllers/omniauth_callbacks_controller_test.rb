# frozen_string_literal: true

require "test_helper"

class OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
    @user = users(:one)
    @admin = users(:admin)
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  test "new google user signs in and goes to onboarding" do
    email = "google-new-#{SecureRandom.hex(4)}@example.com"
    stub_google_auth(sub: "sub-new-#{SecureRandom.hex(4)}", email: email, name: "Google New")

    get "/auth/google_oauth2/callback"

    assert_redirected_to v2_onboarding_path(step: "goal")
    assert cookies[:session_id].present?
    assert User.exists?(email_address: email)
  end

  test "existing user signs in to after authentication url" do
    stub_google_auth(sub: "sub-existing-#{SecureRandom.hex(4)}", email: @user.email_address, name: @user.name)

    get "/auth/google_oauth2/callback"

    assert_redirected_to dashboard_url
    assert cookies[:session_id].present?
  end

  test "admin with otp enabled is challenged before session starts" do
    enable_otp!(@admin)
    stub_google_auth(sub: "sub-admin-#{SecureRandom.hex(4)}", email: @admin.email_address, name: @admin.name)

    get "/auth/google_oauth2/callback"

    assert_redirected_to new_two_factor_session_path
    assert_empty cookies[:session_id].to_s
  end

  test "unverified email redirects to login with alert" do
    stub_google_auth(
      sub: "sub-unverified-#{SecureRandom.hex(4)}",
      email: "unverified-#{SecureRandom.hex(4)}@example.com",
      email_verified: false
    )

    get "/auth/google_oauth2/callback"

    assert_redirected_to new_session_path
    assert_equal I18n.t("auth.google_sign_in_failed"), flash[:alert]
    assert_empty cookies[:session_id].to_s
  end

  test "omniauth failure route redirects to login with alert" do
    get "/auth/failure"

    assert_redirected_to new_session_path
    assert_equal I18n.t("auth.google_sign_in_failed"), flash[:alert]
  end

  private

  def stub_google_auth(sub:, email:, name: "Google User", email_verified: true)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: sub,
      info: {
        email: email,
        name: name,
        email_verified: email_verified
      },
      extra: {
        raw_info: {
          sub: sub,
          email: email,
          name: name,
          email_verified: email_verified
        }
      }
    )
  end

  def enable_otp!(user)
    user.begin_otp_setup!
    user.confirm_otp_setup!(user.totp.now)
  end
end
