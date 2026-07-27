# frozen_string_literal: true

require "test_helper"

class DeveloperRestartNewPlayerExperienceTest < ActiveSupport::TestCase
  test "wipes strategy data and clears onboarding while keeping the account" do
    user = users(:one)
    Onboarding::Run.call(
      user: user,
      area_key: "learning",
      title: "Learn German",
      ideal_scene: "Fluent",
      current_reality: "Beginner",
      today_mission: "Learn 20 words",
      closer_percent: 10,
      route_mission: true
    )
    user.update!(
      support_milestones_shown: %w[adventure_guide first_finished_product],
      strategy_points: 50
    )
    user.strategy_point_ledgers.create!(amount: 50, reason: "test") if user.strategy_point_ledgers.none?

    assert_operator user.strategy_goals.count, :>, 0
    assert_operator user.life_journeys.count, :>, 0

    Developer::RestartNewPlayerExperience.call(user:)

    user.reload
    assert_nil user.onboarding_completed_at
    assert user.needs_onboarding?
    refute user.adventure_guide_done?
    assert_includes user.support_milestones_shown, "first_finished_product"
    assert_equal 0, user.strategy_goals.count
    assert_equal 0, user.life_journeys.count
    assert_equal 0, user.strategy_point_ledgers.count
    assert_equal 0, user.strategy_points
    assert User.exists?(user.id)
  end
end
