# frozen_string_literal: true

require "test_helper"

class MountainTrailToursControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    allow_extra_climbs!(@user)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Write tests",
      closer_percent: 20
    )
  end

  test "updates tour ack" do
    patch mountain_trail_tour_path, params: { ack: 5 }
    assert_response :no_content
    assert_equal 5, @user.reload.mountain_trail_tour_ack
  end

  test "clamps ack to 7" do
    patch mountain_trail_tour_path, params: { ack: 99 }
    assert_response :no_content
    assert_equal 7, @user.reload.mountain_trail_tour_ack
  end
end
