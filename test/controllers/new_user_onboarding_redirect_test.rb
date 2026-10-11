# frozen_string_literal: true

require "test_helper"

class NewUserOnboardingRedirectTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "New Player",
      email_address: "new-player-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      planning_version: 2,
      onboarding_completed_at: nil
    )
  end

  test "signed-in incomplete v2 user visiting root goes to v2 onboarding" do
    sign_in_as @user

    get root_path

    assert_redirected_to v2_onboarding_path
  end

  test "incomplete v2 user logging in goes to v2 onboarding" do
    post session_path, params: {
      email_address: @user.email_address,
      password: "password12345"
    }

    assert_redirected_to v2_onboarding_url
  end
end
