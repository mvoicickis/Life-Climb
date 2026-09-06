# frozen_string_literal: true

require "test_helper"

class CompanionPicksControllerTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  test "update removes overlay via turbo stream without leaving the page" do
    user = users(:one)
    user.update_columns(
      character: "man",
      onboarding_completed_at: Time.current,
      planning_version: 2
    )
    sign_in_as user
    journey = seed_climb!(user)
    project = user.strategy_goals.for_kind("project").order(:position).first

    get life_journey_path(journey, open_camp: project.id)
    assert_response :success
    assert_select "#companion-pick-prompt"

    patch companion_pick_path,
          params: { user: { character: "bee" } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, 'target="companion-pick-prompt"'
    assert_includes response.body, 'action="remove"'

    user.reload
    assert_equal "bee", user.character
    assert user.companion_pick_done?
    refute user.needs_companion_pick?

    get life_journey_path(journey, open_camp: project.id)
    assert_response :success
    assert_select "#companion-pick-prompt", count: 0
  end

  test "legacy overlay pick from dashboard stays on dashboard" do
    user = users(:one)
    user.update_columns(
      character: nil,
      onboarding_completed_at: Time.current,
      planning_version: 2
    )
    sign_in_as user
    seed_climb!(user)

    get dashboard_path
    assert_response :success
    assert_select "#companion-pick-prompt"

    patch companion_pick_path,
          params: { user: { character: "fox" } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal "fox", user.reload.character
    refute user.needs_companion_pick?

    get dashboard_path
    assert_response :success
    assert_select "#companion-pick-prompt", count: 0
  end
end
