require "test_helper"

class V2OnboardingFlowTest < ActionDispatch::IntegrationTest
  test "new registration coach beats land on today's mission" do
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
    assert_redirected_to v2_onboarding_path(step: "want")
    follow_redirect!
    assert_match(/want|career|achieve|Senior|Rails/i, response.body)

    patch v2_onboarding_url(step: "want"), params: {
      onboarding: { ideal_scene: "I am a senior Rails engineer shipping useful products." }
    }
    assert_redirected_to v2_onboarding_path(step: "now")

    patch v2_onboarding_url(step: "now"), params: {
      onboarding: { current_reality: "I am learning Rails every day." }
    }
    assert_redirected_to v2_onboarding_path(step: "next")

    patch v2_onboarding_url(step: "next"), params: {
      onboarding: { next_win: "Finish Rails Fundamentals" }
    }
    assert_redirected_to v2_onboarding_path(step: "today")

    patch v2_onboarding_url(step: "today"), params: {
      onboarding: { today_mission: "Read chapter 5" }
    }
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_match(/Read chapter 5/i, response.body)
    assert_match(/Finish Rails Fundamentals|Next win/i, response.body)
    assert_match(/I did it|I reached this journey/i, response.body)
    assert_no_match(/\bProject\b/, response.body)
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
      next_win: "Finish the first course",
      today_mission: "Complete one lesson",
      closer_percent: 20
    )
    journey = user.primary_focused_journey

    post life_journey_completion_url(journey)
    assert_redirected_to next_mountain_path
    follow_redirect!
    assert_match(/Congratulations|next/i, response.body)
  end
end
