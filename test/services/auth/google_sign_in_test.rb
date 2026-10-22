# frozen_string_literal: true

require "test_helper"

module Auth
  class GoogleSignInTest < ActiveSupport::TestCase
    def google_auth_hash(sub:, email:, email_verified: true, name: "Google User")
      {
        "uid" => sub,
        "info" => {
          "email" => email,
          "name" => name,
          "email_verified" => email_verified
        },
        "extra" => {
          "raw_info" => {
            "sub" => sub,
            "email" => email,
            "email_verified" => email_verified,
            "name" => name
          }
        }
      }
    end

    test "returns existing user when identity matches provider and uid" do
      user = User.create!(
        name: "Linked",
        email_address: "linked-#{SecureRandom.hex(4)}@example.com",
        password: "password12345",
        password_confirmation: "password12345"
      )
      OauthIdentity.create!(user: user, provider: "google", uid: "sub-existing", email: user.email_address)

      result = GoogleSignIn.call(google_auth_hash(sub: "sub-existing", email: user.email_address))

      assert result.ok?
      assert_equal user, result.user
      refute result.new_account
      assert_equal 1, OauthIdentity.where(provider: "google", uid: "sub-existing").count
    end

    test "links verified email to an existing user and creates identity" do
      user = User.create!(
        name: "Password User",
        email_address: "password-user-#{SecureRandom.hex(4)}@example.com",
        password: "password12345",
        password_confirmation: "password12345"
      )

      result = GoogleSignIn.call(
        google_auth_hash(sub: "sub-link-#{SecureRandom.hex(4)}", email: user.email_address)
      )

      assert result.ok?
      assert_equal user, result.user
      refute result.new_account
      identity = OauthIdentity.find_by(provider: "google", user: user)
      assert identity
      assert_equal user.email_address, identity.email
    end

    test "creates a new user and identity when email is verified and unknown" do
      email = "new-google-#{SecureRandom.hex(4)}@example.com"

      result = GoogleSignIn.call(google_auth_hash(sub: "sub-new-#{SecureRandom.hex(4)}", email: email, name: "New Climber"))

      assert result.ok?
      assert result.new_account
      user = result.user
      assert user.persisted?
      assert_equal "New Climber", user.name
      assert_equal email, user.email_address
      assert_equal "fox", user.character
      assert user.companion_pick_done?
      assert user.password_digest.present?
      assert OauthIdentity.exists?(user: user, provider: "google", email: email)
    end

    test "rejects unverified email without creating user or identity" do
      email = "unverified-#{SecureRandom.hex(4)}@example.com"

      result = GoogleSignIn.call(
        google_auth_hash(sub: "sub-unverified", email: email, email_verified: false)
      )

      refute result.ok?
      assert_equal :email_unverified, result.reason
      assert_nil result.user
      refute result.new_account
      refute User.exists?(email_address: email)
      refute OauthIdentity.exists?(provider: "google", uid: "sub-unverified")
    end

    test "prefers existing identity uid over matching email on another user" do
      identity_user = User.create!(
        name: "Identity Owner",
        email_address: "identity-owner-#{SecureRandom.hex(4)}@example.com",
        password: "password12345",
        password_confirmation: "password12345"
      )
      other_user = User.create!(
        name: "Email Match",
        email_address: "email-match-#{SecureRandom.hex(4)}@example.com",
        password: "password12345",
        password_confirmation: "password12345"
      )
      OauthIdentity.create!(
        user: identity_user,
        provider: "google",
        uid: "sub-shared",
        email: identity_user.email_address
      )

      result = GoogleSignIn.call(google_auth_hash(sub: "sub-shared", email: other_user.email_address))

      assert result.ok?
      assert_equal identity_user, result.user
      refute result.new_account
      refute OauthIdentity.exists?(user: other_user, provider: "google")
    end

    test "normalizes email case and whitespace when linking" do
      stored = "normalize-me-#{SecureRandom.hex(4)}@example.com"
      user = User.create!(
        name: "Normalize",
        email_address: stored,
        password: "password12345",
        password_confirmation: "password12345"
      )

      result = GoogleSignIn.call(
        google_auth_hash(sub: "sub-normalize", email: "  #{stored.upcase}  ")
      )

      assert result.ok?
      assert_equal user, result.user
      assert_equal stored, OauthIdentity.find_by(provider: "google", uid: "sub-normalize").email
    end
  end
end
