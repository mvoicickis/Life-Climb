# frozen_string_literal: true

require "test_helper"

class StrategyUpcomingBattleTest < ActiveSupport::TestCase
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

  test "returns tomorrow battle when scheduled" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Project", position: 0
    )
    project_leaf = practice_leaf_for!(project)
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project_leaf, horizon: "day",
      title: "Today fight", scheduled_on: Date.current, position: 0
    )
    project_leaf = practice_leaf_for!(project)
    tomorrow = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project_leaf, horizon: "day",
      title: "Tomorrow fight", scheduled_on: Date.current + 1.day, position: 0
    )

    upcoming = Strategy::UpcomingBattle.for(user: @user, journey: @journey)
    assert_equal "Tomorrow fight", upcoming[:title]
    assert_equal true, upcoming[:tomorrow]
    assert_equal tomorrow.scheduled_on, upcoming[:scheduled_on]
  end

  test "returns nil when no future battles" do
    upcoming = Strategy::UpcomingBattle.for(user: @user, journey: @journey)
    assert_nil upcoming
  end
end
