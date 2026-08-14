# frozen_string_literal: true

require "test_helper"

class Strategy::PathProjectTest < ActiveSupport::TestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @journey = seed_goal_only!
  end

  test "ensure! uses the holding camp when no visible path Project exists" do
    assert_nil Strategy::PathProject.resolve(user: @user, journey: @journey)

    project = Strategy::PathProject.ensure!(
      user: @user,
      journey: @journey,
      title: "Ship LifePoints MVP"
    )

    assert project.holding?
    assert project.path_level_camp?
    assert project.parent.holding?
    assert project.parent.plan?
    refute_equal "Ship LifePoints MVP", project.title
    refute_equal "Ship LifePoints MVP", project.parent.title
  end

  test "resolve returns the only incomplete path Project" do
    plan = create_plan!("Build")
    only = create_path_project!(plan, "Auth", position: 0)

    assert_equal only, Strategy::PathProject.resolve(user: @user, journey: @journey)
  end

  test "resolve prefers last-touched incomplete path Project when several exist" do
    plan = create_plan!("Build")
    first = create_path_project!(plan, "First camp", position: 0)
    second = create_path_project!(plan, "Second camp", position: 1)

    leaf = second
    day = leaf.children.create!(
      user: @user,
      life_area: @journey.life_area,
      life_journey: @journey,
      horizon: "day",
      title: "Recent fight",
      scheduled_on: Date.current,
      position: 0
    )
    day.update_columns(updated_at: 1.minute.from_now)

    assert_equal second, Strategy::PathProject.resolve(user: @user, journey: @journey)
    refute_equal first, Strategy::PathProject.resolve(user: @user, journey: @journey)
  end

  test "ensure! is a no-op create when resolve already finds a project" do
    plan = create_plan!("Build")
    existing = create_path_project!(plan, "Auth", position: 0)

    assert_no_difference -> { @user.strategy_goals.where(horizon: "project").count } do
      assert_equal existing, Strategy::PathProject.ensure!(
        user: @user,
        journey: @journey,
        title: "Ignored title"
      )
    end
  end

  private

  def seed_goal_only!
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App live",
      current_reality: "Building",
      today_mission: "Plan the path",
      closer_percent: 10,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @user.reload.primary_focused_journey
  end

  def create_plan!(title)
    goal = @user.strategy_goals.for_kind("goal").roots.first
    goal.children.create!(
      user: @user,
      life_area: @journey.life_area,
      life_journey: @journey,
      horizon: "plan",
      title: title,
      position: 0
    )
  end

  def create_path_project!(plan, title, position:)
    plan.children.create!(
      user: @user,
      life_area: @journey.life_area,
      life_journey: @journey,
      horizon: "project",
      title: title,
      position: position
    )
  end
end
