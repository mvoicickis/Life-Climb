# frozen_string_literal: true

require "test_helper"

class AreaRelevantJourneyCopyTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    LifeAreas::Select.call(user: @user, keys: %w[relationships])
    area = @user.life_areas.v2_selected.find_by!(key: "relationships")
    @journey = @user.life_journeys.create!(
      life_area: area,
      title: "Rebuild connection",
      ideal_scene: "Warm weekly dates",
      current_reality: "We drift during the week",
      next_win: "Three date nights",
      status: "active",
      gap_percent: 70,
      setup_flags: { "goal" => "done" },
      activated_at: Time.current
    )
    Focus::SetJourneys.call(user: @user, journey_ids: [ @journey.id ])
  end

  test "journey planner shows plain scale and plan-together note" do
    get life_journey_path(@journey, horizon: "brief")
    assert_response :success
    assert_match(/Your year plan|Why it matters|My rules/i, response.body)
    assert_match(/Plan it together/i, response.body)
    assert_match(/Message me anytime/i, response.body)
    assert_no_match(/Senior Rails developer shipping products/i, response.body)
  end

  test "home battle placeholder is relationship flavored" do
    get dashboard_path
    assert_response :success
    assert_match(/calendar|message|date|friend|plan/i, response.body)
  end
end
