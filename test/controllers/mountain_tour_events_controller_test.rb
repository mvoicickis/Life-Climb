# frozen_string_literal: true

require "test_helper"

class MountainTourEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "tracks viewed event" do
    assert_difference -> { @user.user_events.named("mountain_tour_step_viewed").count }, 1 do
      post mountain_tour_events_path, params: { event: "viewed", step: "today" }
    end

    assert_response :no_content
    event = @user.user_events.named("mountain_tour_step_viewed").last
    assert_equal "today", event.properties["step"]
  end

  test "tracks completed event" do
    assert_difference -> { @user.user_events.named("mountain_tour_step_completed").count }, 1 do
      post mountain_tour_events_path, params: { event: "completed", step: "today" }
    end

    assert_response :no_content
    event = @user.user_events.named("mountain_tour_step_completed").last
    assert_equal "today", event.properties["step"]
  end

  test "rejects invalid step" do
    assert_no_difference -> { UserEvent.count } do
      post mountain_tour_events_path, params: { event: "viewed", step: "goal" }
    end

    assert_response :unprocessable_entity
  end

  test "rejects invalid event" do
    assert_no_difference -> { UserEvent.count } do
      post mountain_tour_events_path, params: { event: "skipped", step: "today" }
    end

    assert_response :unprocessable_entity
  end
end
