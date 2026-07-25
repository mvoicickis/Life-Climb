require "test_helper"

class V2OnboardingFlowTest < ActionDispatch::IntegrationTest
  test "new registration lands on calm v2 onboarding and reaches dashboard" do
    post registration_url, params: {
      user: {
        email_address: "fresh@example.com",
        password: "password12345",
        password_confirmation: "password12345"
      }
    }
    assert_redirected_to v2_onboarding_path

    follow_redirect!
    assert_response :success
    assert_match(/What matters/, response.body)

    patch v2_onboarding_url(step: "areas"), params: {
      onboarding: { area_keys: %w[career self] }
    }
    assert_redirected_to v2_onboarding_path(step: "journey")

    patch v2_onboarding_url(step: "journey"), params: {
      onboarding: {
        ideal_scene: "I am healthy, calm, and building useful software.",
        current_reality: "I am starting and learning every day.",
        title: "Alive builder",
        closer_percent: 25
      }
    }
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_match(/What I'm working on|What I should do today|Am I making progress/i, response.body)
    assert_match(/I did it|Done for today|One step toward/, response.body)
  end
end
