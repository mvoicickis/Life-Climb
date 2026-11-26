# frozen_string_literal: true

require "test_helper"

class ReferralsAttributionTest < ActionDispatch::IntegrationTest
  setup do
    BetaSignup.delete_all
    OmniAuth.config.test_mode = true
    @referrer = users(:one)
    @existing = users(:two)
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  test "r param sets cookie then email signup attributes referrer" do
    get root_path, params: { r: @referrer.referral_code }
    assert_response :success

    email = "referred-#{SecureRandom.hex(4)}@example.com"
    assert_difference("User.count", 1) do
      post registration_url, params: {
        user: {
          name: "Referred",
          email_address: email,
          password: "password12345"
        }
      }
    end

    user = User.find_by!(email_address: email)
    assert_equal @referrer.id, user.referred_by_id
  end

  test "unknown referral code is ignored" do
    get root_path, params: { r: "not-a-real-code" }
    assert_response :success

    email = "no-ref-#{SecureRandom.hex(4)}@example.com"
    post registration_url, params: {
      user: {
        name: "Solo",
        email_address: email,
        password: "password12345"
      }
    }

    user = User.find_by!(email_address: email)
    assert_nil user.referred_by_id
  end

  test "first valid referral code wins in cookie" do
    other = users(:two)
    get root_path, params: { r: @referrer.referral_code }
    get root_path, params: { r: other.referral_code }

    post beta_signups_path,
         params: { beta_signup: { email: "first-wins@example.com", source_path: "/" } },
         as: :turbo_stream

    signup = BetaSignup.find_by!(email: "first-wins@example.com")
    assert_equal @referrer.id, signup.referred_by_id
  end

  test "google new user gets referrer from cookie" do
    get root_path, params: { r: @referrer.referral_code }

    email = "google-ref-#{SecureRandom.hex(4)}@example.com"
    stub_google_auth(sub: "sub-ref-#{SecureRandom.hex(4)}", email: email, name: "Google Ref")

    get "/auth/google_oauth2/callback"

    user = User.find_by!(email_address: email)
    assert_equal @referrer.id, user.referred_by_id
  end

  test "google sign in for existing user does not set referred_by" do
    get root_path, params: { r: @referrer.referral_code }
    stub_google_auth(
      sub: "sub-existing-ref-#{SecureRandom.hex(4)}",
      email: @existing.email_address,
      name: @existing.name
    )

    get "/auth/google_oauth2/callback"

    assert_nil @existing.reload.referred_by_id
  end

  test "beta signup with cookie stores referred_by_id" do
    get root_path, params: { r: @referrer.referral_code }

    post beta_signups_path,
         params: { beta_signup: { email: "beta-ref@example.com", source_path: "/" } },
         as: :turbo_stream

    signup = BetaSignup.find_by!(email: "beta-ref@example.com")
    assert_equal @referrer.id, signup.referred_by_id
  end

  test "waitlist referrer copies to account on signup without cookie" do
    BetaSignup.create!(
      email: "waitlist-copy@example.com",
      source_path: "/",
      referred_by_id: @referrer.id
    )

    post registration_url, params: {
      user: {
        name: "From Waitlist",
        email_address: "waitlist-copy@example.com",
        password: "password12345"
      }
    }

    user = User.find_by!(email_address: "waitlist-copy@example.com")
    assert_equal @referrer.id, user.referred_by_id
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
end