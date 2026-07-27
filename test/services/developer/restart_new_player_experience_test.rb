# frozen_string_literal: true

require "test_helper"

class DeveloperRestartNewPlayerExperienceTest < ActiveSupport::TestCase
  test "clears onboarding and adventure guide without deleting strategy data" do
    user = users(:one)
    user.update!(
      onboarding_completed_at: Time.current,
      support_milestones_shown: %w[adventure_guide first_finished_product],
      planning_version: 2
    )

    goal_count = user.strategy_goals.count
    journey_count = user.life_journeys.count

    Developer::RestartNewPlayerExperience.call(user:)

    user.reload
    assert_nil user.onboarding_completed_at
    assert user.needs_onboarding?
    refute user.adventure_guide_done?
    assert_includes user.support_milestones_shown, "first_finished_product"
    assert_equal goal_count, user.strategy_goals.count
    assert_equal journey_count, user.life_journeys.count
  end
end
