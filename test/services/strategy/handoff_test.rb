# frozen_string_literal: true

require "test_helper"

class StrategyHandoffTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
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
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
  end

  test "empty strategy points at locking the goal" do
    handoff = Strategy::Handoff.for(user: @user, journey: @journey)
    assert_match(/Lock your season goal/i, handoff[:label])
  end

  test "project handoff names the plan" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Become debt-free", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Find a job", position: 0
    )
    handoff = Strategy::Handoff.for(user: @user, journey: @journey)
    assert_match(/Add a project under “Find a job”/i, handoff[:label])
    assert_includes handoff[:href], "focus_id=#{plan.id}"
  end

  test "handoff focuses the same path Project PathProject would resolve" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Become debt-free", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Find a job", position: 0
    )
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project",
      title: "First camp", position: 0
    )
    second = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project",
      title: "Second camp", position: 1
    )
    leaf = second
    day = leaf.children.create!(
      user: @user, life_area: @area, life_journey: @journey, horizon: "day",
      title: "Touch second", scheduled_on: Date.current, position: 0
    )
    day.update_columns(updated_at: 1.minute.from_now)

    resolved = Strategy::PathProject.resolve(user: @user, journey: @journey)
    assert_equal second, resolved

    handoff = Strategy::Handoff.for(user: @user, journey: @journey)
    # Nested battle exists → open_strategy, still focused on the resolved camp
    assert_match(/Continue on Mountain/i, handoff[:label])
    assert_includes handoff[:href], "focus_id=#{second.id}"
  end

  test "add_battle names the resolved empty path Project" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Become debt-free", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Find a job", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project",
      title: "Auth", position: 0
    )

    assert_equal project, Strategy::PathProject.resolve(user: @user, journey: @journey)
    handoff = Strategy::Handoff.for(user: @user, journey: @journey)
    assert_match(/Add today’s battle under “Auth”/i, handoff[:label])
    assert_includes handoff[:href], "focus_id=#{project.id}"
  end

  test "open_strategy when nested battles exist under path Project" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Become debt-free", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Find a job", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project",
      title: "Auth", position: 0
    )
    leaf = project
    leaf.children.create!(
      user: @user, life_area: @area, life_journey: @journey, horizon: "day",
      title: "Nested fight", scheduled_on: Date.current, position: 0
    )

    assert project.children.for_kind("day").any?
    assert Strategy::Progress.battles_under(project).any?

    handoff = Strategy::Handoff.for(user: @user, journey: @journey)
    assert_match(/Continue on Mountain/i, handoff[:label])
    refute_match(/Add today’s battle/i, handoff[:label])
  end
end
