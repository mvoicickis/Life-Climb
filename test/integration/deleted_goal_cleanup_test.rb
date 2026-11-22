# frozen_string_literal: true

require "test_helper"

class DeletedGoalCleanupTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper
  include TodayV2TestHelper

  setup do
    @user = users(:one)
    @user.update!(planning_version: 2, onboarding_completed_at: Time.current)
    sign_in_as @user
    allow_extra_climbs!(@user)
    @focused = seed_climb!(@user, area_key: "career", title: "Focused peak", today_mission: "Focused fight")
    dismiss_onboarding_missions!(@user)
  end

  test "deleting the only goal archives the journey and lands on my world" do
    goal = root_goal_for(@focused)

    delete strategy_goal_path(goal)
    assert_redirected_to world_path

    @focused.reload
    assert_equal "archived", @focused.status
    assert_nil @focused.focus_position

    get world_path
    assert_response :success
    assert_select ".lp-my-world-sheet__mtn-title", text: "Focused peak", count: 0
    assert_select ".lp-my-world__reach", text: I18n.t("my_world.reaches", count: 0)
  end

  test "deleting one goal focuses the survivor and hides the deleted climb from my world and other mountains" do
    other = seed_second_journey!(title: "Other peak", area_key: "self", battle_title: "Other fight")
    other_camp = @user.strategy_goals.find_by!(horizon: "project", life_journey_id: other.id)
    other_camp.children.create!(
      user: @user, life_area: other.life_area, life_journey: other,
      horizon: "day", title: "Extra fight", scheduled_on: Date.current, position: 1
    )

    goal = root_goal_for(@focused)
    delete strategy_goal_path(goal)
    assert_redirected_to life_journey_path(other)

    @focused.reload
    assert_equal "archived", @focused.status
    assert_equal 1, @user.life_journeys.with_destination.count
    assert_equal other.id, @user.reload.primary_focused_journey&.id

    get world_path
    assert_response :success
    assert_select ".lp-my-world-sheet__mtn-title", text: "Focused peak", count: 0
    assert_select ".lp-my-world-sheet__mtn-title", text: "Other peak"

    get dashboard_path
    assert_response :success
    assert_select ".lp-other-mountains-row__name", text: "Focused peak", count: 0
    assert_select ".lp-other-mountains-row", count: 0
  end

  private

  def root_goal_for(journey)
    @user.strategy_goals.for_kind("goal").roots.find_by!(life_journey_id: journey.id)
  end
end