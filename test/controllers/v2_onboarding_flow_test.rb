require "test_helper"

class V2OnboardingFlowTest < ActionDispatch::IntegrationTest
  test "new registration picks one area, interviews, and reaches dashboard" do
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
    assert_match(/biggest positive difference/i, response.body)

    patch v2_onboarding_url(step: "area"), params: {
      onboarding: { area_key: "career" }
    }
    assert_redirected_to v2_onboarding_path(step: "interview")
    follow_redirect!
    assert_match(/career|Senior|Rails/i, response.body)

    patch v2_onboarding_url(step: "interview"), params: {
      onboarding: {
        area_key: "career",
        ideal_scene: "I am a senior Rails engineer shipping useful products.",
        current_reality: "I am learning Rails every day.",
        title: "Senior Rails path",
        closer_percent: 25
      }
    }
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_match(/What I'm working on|What I should do today|I did it|One step toward/i, response.body)
    assert_match(/I reached this journey/i, response.body)
  end

  test "completing a journey opens next mountain choice" do
    user = users(:one)
    sign_in_as user
    Onboarding::Run.call(
      user: user,
      area_key: "learning",
      title: "Learn Rails",
      ideal_scene: "Fluent Rails",
      current_reality: "Beginner",
      closer_percent: 20
    )
    journey = user.primary_focused_journey

    post life_journey_completion_url(journey)
    assert_redirected_to next_mountain_path
    follow_redirect!
    assert_match(/Congratulations|next/i, response.body)
  end
end
