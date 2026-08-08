# frozen_string_literal: true

require "test_helper"

class Trackers::CreateImprovementProjectTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "Calm days",
      current_reality: "Building",
      next_win: "Beta",
      today_mission: "Write tests",
      closer_percent: 20,
      route_mission: true
    )
    @user.reload
    @journey = @user.primary_focused_journey
    @habit = habits(:one)
    @area = @user.areas.create!(name: "Health")
    @habit.update!(area: @area, state: "attention")
  end

  test "creates plan when spine has only a goal" do
    goal = @user.strategy_goals.for_area(@journey.life_area_id).for_kind("goal").roots.first
    assert goal
    goal.children.for_kind("plan").destroy_all
    assert_equal 0, goal.children.for_kind("plan").count

    project = Trackers::CreateImprovementProject.call(user: @user, habit: @habit)
    assert project.path_level_camp?
    assert_equal @habit.id, project.habit_id
    assert project.parent.plan?
    assert_equal @journey.id, project.life_journey_id
  end

  test "prefers habit linked journey over primary" do
    other = @user.life_journeys.create!(
      life_area: @journey.life_area,
      title: "Side mountain",
      ideal_scene: "Elsewhere",
      current_reality: "Other",
      next_win: "Win",
      gap_percent: 70,
      status: "active"
    )
    goal = @user.strategy_goals.create!(
      life_area: other.life_area, life_journey: other, horizon: "goal", title: "Other season", position: 1
    )
    @user.strategy_goals.create!(
      life_area: other.life_area, life_journey: other, parent: goal, horizon: "plan", title: "Other path", position: 0
    )
    @habit.update!(life_journey: other)

    project = Trackers::CreateImprovementProject.call(user: @user, habit: @habit)
    assert_equal other.id, project.life_journey_id
  end

  test "reuses existing habit-linked project instead of creating a duplicate" do
    first = Trackers::CreateImprovementProject.call(user: @user, habit: @habit)
    assert_no_difference -> { @user.strategy_goals.where(habit_id: @habit.id).count } do
      second = Trackers::CreateImprovementProject.call(user: @user, habit: @habit)
      assert_equal first.id, second.id
    end
  end

  test "idempotent reuse works even when tracker is no longer attention" do
    first = Trackers::CreateImprovementProject.call(user: @user, habit: @habit)
    @habit.update!(state: "good")

    second = Trackers::CreateImprovementProject.call(user: @user, habit: @habit)
    assert_equal first.id, second.id
  end
end
