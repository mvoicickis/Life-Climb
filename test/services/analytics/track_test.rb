# frozen_string_literal: true

require "test_helper"

class Analytics::TrackTest < ActiveSupport::TestCase
  test "creates a user event with properties" do
    user = users(:one)

    assert_difference -> { user.user_events.count }, 1 do
      Analytics::Track.call(
        user: user,
        name: "onboarding_step_viewed",
        properties: { step: "goal" }
      )
    end

    event = user.user_events.last
    assert_equal "onboarding_step_viewed", event.name
    assert_equal "goal", event.properties["step"]
  end
end
