# frozen_string_literal: true

require "test_helper"

class JourneySetupTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App in production",
      current_reality: "Still building",
      next_win: "Launch Beta",
      today_mission: "Write one test",
      closer_percent: 20
    )
    @journey = @user.reload.primary_focused_journey
  end

  test "journey page shows editable alignment sections" do
    get life_journey_path(@journey)
    assert_response :success
    assert_match(/Set up this journey/i, response.body)
    assert_match(/Why it matters/i, response.body)
    assert_match(/Rules/i, response.body)
    assert_match(/Approach/i, response.body)
    assert_match(/Program/i, response.body)
    assert_match(/Finished result/i, response.body)
    assert_match(/Today'?s action|Today/i, response.body)
  end

  test "can save alignment fields from journey page" do
    patch life_journey_path(@journey), params: {
      life_journey: {
        title: "Ship LifePoints",
        purpose: "Freedom and mastery",
        policy: "Ship weekly",
        approach: "Build in public",
        program: "1) MVP 2) Beta 3) Launch",
        next_win: "Launch Beta",
        ideal_scene: "App in production",
        current_reality: "Still building",
        finished_result: "A live product people pay for",
        closer_percent: 35,
        today_mission: "Polish journey setup"
      }
    }
    assert_redirected_to life_journey_path(@journey)
    @journey.reload
    assert_equal "Freedom and mastery", @journey.purpose
    assert_equal "Ship weekly", @journey.policy
    assert_equal "Build in public", @journey.approach
    assert_equal "1) MVP 2) Beta 3) Launch", @journey.program
    assert_equal "A live product people pay for", @journey.finished_result
    assert_in_delta 65.0, @journey.gap_percent.to_f, 0.01
    mission = @journey.missions.for_day.primary.order(:id).first
    assert_equal "Polish journey setup", mission.title
  end
end
