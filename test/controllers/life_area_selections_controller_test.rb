# frozen_string_literal: true

require "test_helper"

class LifeAreaSelectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "show renders catalog as single choice" do
    get life_area_selections_url
    assert_response :success
    assert_match(/Career/, response.body)
    assert_match(/Purpose/, response.body)
    assert_match(/Relationships|Love/i, response.body)
    assert_select "input[type=radio][name=key]"
    assert_select "input[type=checkbox][name='keys[]']", count: 0
  end

  test "update selects exactly one area" do
    patch life_area_selections_url, params: { key: "learning" }
    assert_redirected_to new_life_journey_path

    @user.reload
    assert @user.planning_v2?
    assert_equal %w[learning], @user.life_areas.v2_selected.pluck(:key)
  end

  test "rejects multiple areas" do
    patch life_area_selections_url, params: { keys: %w[self learning] }
    assert_redirected_to life_area_selections_url
    follow_redirect!
    assert_match(/only one/i, flash[:alert].to_s + response.body)
  end

  test "switching area does not destroy journeys on previous area" do
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
    journey = @user.reload.primary_focused_journey
    career = journey.life_area
    assert_equal "career", career.key

    patch life_area_selections_url, params: { key: "relationships" }
    assert_response :redirect

    career.reload
    assert_nil career.selected_at
    assert LifeJourney.exists?(journey.id)
    assert_equal %w[relationships], @user.life_areas.v2_selected.pluck(:key)
  end
end
