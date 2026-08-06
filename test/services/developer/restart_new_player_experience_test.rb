# frozen_string_literal: true

require "test_helper"

class DeveloperRestartNewPlayerExperienceTest < ActiveSupport::TestCase
  include ClimbTestHelper

  test "wipes strategy data and clears onboarding while keeping the account" do
    user = users(:one)
    user.update_columns(developer: true, total_points: 120, character: "fox")
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
    assert_nil user.character
    refute user.character_chosen?
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

    # Kept: account, developer flag, Action Points
    assert User.exists?(user.id)
    assert user.read_attribute(:developer)
    assert_equal action_points_before, user.total_points
  end

  test "wipes habits together with daily logs and completions" do
    user = users(:one)
    user.update_columns(developer: true, planning_version: 2)

    habit = user.habits.create!(
      name: "Walk",
      unit: "minutes",
      points: 5,
      frequency: "daily",
      position: 0
    )
    user.daily_logs.create!(habit: habit, logged_on: Date.current, amount: 20, goal: 30)
    user.completions.create!(habit: habit, completed_on: Date.current, points_awarded: 5)

    assert_operator user.habits.count, :>, 0
    assert_operator user.daily_logs.count, :>, 0
    assert_operator user.completions.count, :>, 0

    Developer::RestartNewPlayerExperience.call(user:)

    user.reload
    assert_equal 0, user.habits.count
    assert_equal 0, user.daily_logs.count
    assert_equal 0, user.completions.count
  end

  test "succeeds when a quantity log still points at a daily todo" do
    user = users(:one)
    user.update_columns(developer: true)

    Onboarding::Run.call(
      user: user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "Shipped",
      current_reality: "Building",
      today_mission: "Write tests",
      closer_percent: 10,
      route_mission: true
    )

    area = user.primary_focused_journey.life_area
    goal = user.strategy_goals.for_kind("goal").roots.first
    plan = user.strategy_goals.create!(
      life_area: area, life_journey: goal.life_journey, parent: goal,
      horizon: "plan", title: "Build", position: 0
    )
    project = user.strategy_goals.create!(
      life_area: area, life_journey: goal.life_journey, parent: plan,
      horizon: "project", title: "Pages", position: 0,
      target_amount: 100, unit: "pages", current_amount: 0
    )
    leaf = practice_leaf_for!(project)
    day = user.strategy_goals.create!(
      life_area: area, life_journey: goal.life_journey, parent: leaf,
      horizon: "day", title: "Read", scheduled_on: Date.current, position: 0
    )
    todo = user.daily_todos.create!(
      title: "Read pages",
      aspect_key: "career",
      scheduled_on: Date.current,
      strategy_goal: day,
      position: 0
    )
    user.strategy_quantity_logs.create!(
      strategy_goal: project,
      source_day: day,
      daily_todo: todo,
      amount: 12,
      unit: "pages",
      logged_on: Date.current
    )

    assert_operator user.strategy_quantity_logs.count, :>, 0

    assert_nothing_raised do
      Developer::RestartNewPlayerExperience.call(user:)
    end

    user.reload
    assert_equal 0, user.strategy_quantity_logs.count
    assert_equal 0, user.daily_todos.count
    assert_nil user.onboarding_completed_at
    assert_nil user.character
    refute user.character_chosen?
  end
end
