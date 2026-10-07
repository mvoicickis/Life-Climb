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

  test "resolve picks trail current camp when stage order differs from position" do
    plan = create_plan!("Build")
    camp_a = create_path_project!(plan, "Camp A", position: 3)
    camp_b = create_path_project!(plan, "Camp B", position: 0)
    camp_c = create_path_project!(plan, "Camp C", position: 1)
    camp_d = create_path_project!(plan, "Camp D", position: 2)
    [ [ camp_a, 0 ], [ camp_b, 1 ], [ camp_c, 2 ], [ camp_d, 3 ] ].each do |camp, stage|
      camp.update_columns(stage: stage)
    end

    camp_a.complete!
    battle_b = camp_b.children.create!(
      user: @user,
      life_area: @journey.life_area,
      life_journey: @journey,
      horizon: "day",
      title: "B fight",
      scheduled_on: Date.current,
      position: 0
    )
    battle_b.complete!

    assert_equal camp_b, Strategy::Trail.current_camp_for(plan: plan.reload)
    assert_equal camp_b, Strategy::PathProject.resolve(user: @user, journey: @journey)
    refute_equal camp_d, Strategy::PathProject.resolve(user: @user, journey: @journey)
  end

  test "resolve stays on trail current when a later camp has a newer day" do
    plan = create_plan!("Build")
    camp_b = create_path_project!(plan, "Camp B", position: 0)
    camp_d = create_path_project!(plan, "Camp D", position: 2)
    camp_b.update_columns(stage: 1)
    camp_d.update_columns(stage: 3)

    battle_b = camp_b.children.create!(
      user: @user,
      life_area: @journey.life_area,
      life_journey: @journey,
      horizon: "day",
      title: "B fight",
      scheduled_on: Date.current,
      position: 0
    )
    battle_b.complete!

    day_d = camp_d.children.create!(
      user: @user,
      life_area: @journey.life_area,
      life_journey: @journey,
      horizon: "day",
      title: "D placeholder",
      scheduled_on: Date.current + 7,
      position: 0
    )
    day_d.update_columns(updated_at: 1.hour.from_now)

    assert_equal camp_b, Strategy::PathProject.resolve(user: @user, journey: @journey)
  end

  test "resolve skips a finished plan and returns open camp on the next plan" do
    allow_extra_climbs!(@user)

    plan_done = create_plan!("Done path")
    plan_done.update_columns(position: 0)
    done_camp = create_path_project!(plan_done, "Summit", position: 0)
    done_camp.complete!

    plan_open = create_plan!("Next path")
    plan_open.update_columns(position: 1)
    open_camp = create_path_project!(plan_open, "Fresh camp", position: 0)

    resolved = Strategy::PathProject.resolve(user: @user, journey: @journey)
    assert_equal open_camp, resolved
    refute resolved.holding?
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
