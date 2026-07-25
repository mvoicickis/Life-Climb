require "test_helper"

class OnboardingExamplesTest < ActionDispatch::IntegrationTest
  test "dream step shows tapable life examples" do
    user = User.create!(
      email_address: "fresh-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )
    sign_in_as user

    get onboarding_path(step: "dream")
    assert_response :success
    assert_match(/Feel free with money/, response.body)
    assert_match(/Ideas you can tap/, response.body)
    refute_match(/Ruby on Rails/, response.body)
  end

  test "goal step shows everyday goal examples" do
    user = User.create!(
      email_address: "fresh-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )
    sign_in_as user
    # seed draft dream via session by posting dream first
    patch onboarding_path, params: { step: "dream", onboarding: { dream: "Feel free with money" } }
    follow_redirect!

    assert_response :success
    assert_match(/Save 3 months of living costs/, response.body)
    assert_match(/Run for 30 minutes/, response.body)
  end
end
