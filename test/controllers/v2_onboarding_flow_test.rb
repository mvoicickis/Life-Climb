require "test_helper"

class V2OnboardingFlowTest < ActionDispatch::IntegrationTest
  test "mvp coach flow: area journey vision reality progress milestone mission" do
    post registration_url, params: {
      user: {
        name: "Alex",
        email_address: "fresh@example.com",
        password: "password12345",
        password_confirmation: "password12345"
      }
    }
    assert_redirected_to v2_onboarding_path

    follow_redirect!
    assert_response :success
    assert_match(/improve first|Which area/i, response.body)

    patch v2_onboarding_url(step: "area"), params: {
      onboarding: { area_key: "career" }
    }
    assert_redirected_to v2_onboarding_path(step: "journey")
    follow_redirect!
    assert_match(/want to achieve/i, response.body)

    patch v2_onboarding_url(step: "journey"), params: {
      onboarding: { title: "Become a Senior Rails Developer" }
    }
    assert_redirected_to v2_onboarding_path(step: "vision")

    patch v2_onboarding_url(step: "vision"), params: {
      onboarding: { ideal_scene: "Working as a Rails developer building products I love." }
    }
    assert_redirected_to v2_onboarding_path(step: "reality")

    patch v2_onboarding_url(step: "reality"), params: {
      onboarding: { current_reality: "Learning Rails and building personal projects." }
    }
    assert_redirected_to v2_onboarding_path(step: "progress")

    patch v2_onboarding_url(step: "progress"), params: {
      onboarding: { closer_percent: 5 }
    }
    assert_redirected_to v2_onboarding_path(step: "milestone")

    patch v2_onboarding_url(step: "milestone"), params: {
      onboarding: { next_win: "Finish Rails Fundamentals" }
    }
    assert_redirected_to v2_onboarding_path(step: "mission")

    patch v2_onboarding_url(step: "mission"), params: {
      onboarding: { today_mission: "Read 20 pages" }
    }
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_match(/Alex/i, response.body)
    assert_match(/Read 20 pages/i, response.body)
    assert_match(/Today.?s Battle|Complete Today.?s Battle|Complete Battle/i, response.body)
    assert_match(/Today.?s Goal|Today.?s Battle|Complete Today.?s Battle|Complete Battle/i, response.body)
    assert_no_match(/Life Tree|Open Life/i, response.body)
  end

  test "milestone can be skipped" do
    post registration_url, params: {
      user: {
        name: "Sam",
        email_address: "skipmile@example.com",
        password: "password12345",
        password_confirmation: "password12345"
      }
    }
    follow_redirect!

    patch v2_onboarding_url(step: "area"), params: { onboarding: { area_key: "career" } }
    patch v2_onboarding_url(step: "journey"), params: { onboarding: { title: "Ship my app" } }
    patch v2_onboarding_url(step: "vision"), params: { onboarding: { ideal_scene: "App in production" } }
    patch v2_onboarding_url(step: "reality"), params: { onboarding: { current_reality: "Still building" } }
    patch v2_onboarding_url(step: "progress"), params: { onboarding: { closer_percent: 10 } }
    patch v2_onboarding_url(step: "milestone"), params: { skip: 1 }
    assert_redirected_to v2_onboarding_path(step: "mission")

    patch v2_onboarding_url(step: "mission"), params: { onboarding: { today_mission: "Write one test" } }
    assert_redirected_to dashboard_path
    user = User.find_by!(email_address: "skipmile@example.com")
    assert_nil user.life_journeys.last.next_win.presence
    assert_equal "Write one test", user.missions.last.title
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
