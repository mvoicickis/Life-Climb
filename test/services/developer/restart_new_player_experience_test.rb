# frozen_string_literal: true

require "test_helper"

class DeveloperRestartNewPlayerExperienceTest < ActiveSupport::TestCase
  test "wipes strategy data and clears onboarding while keeping the account" do
    user = users(:one)
    user.update_columns(developer: true, total_points: 120)
    habit_ids = user.habits.pluck(:id)
    action_points_before = user.total_points

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
    assert_operator user.life_areas.count, :>, 0

    day = user.strategy_goals.battles.first || user.strategy_goals.first
    day.update_columns(horizon: "day", scheduled_on: Date.current) unless day.day?
    user.practice_tasks.create!(strategy_goal: day, title: "Orphan me", position: 0)
    assert_operator user.practice_tasks.count, :>, 0

    Developer::RestartNewPlayerExperience.call(user:)

    user.reload
    assert_nil user.onboarding_completed_at
    assert user.needs_onboarding?
    refute user.adventure_guide_done?
    assert_includes user.support_milestones_shown, "first_finished_product"
    assert_equal 0, user.strategy_goals.count
    assert_equal 0, user.life_journeys.count
    assert_equal 0, user.life_areas.count
    assert_equal 0, user.daily_todos.count
    assert_equal 0, user.practice_tasks.count
    assert_equal 0, user.strategy_point_ledgers.count
    assert_equal 0, user.strategy_points

    # Kept: account, developer flag, Action Points, habits
    assert User.exists?(user.id)
    assert user.read_attribute(:developer)
    assert_equal action_points_before, user.total_points
    assert_equal habit_ids.sort, user.habits.pluck(:id).sort
  end
end
