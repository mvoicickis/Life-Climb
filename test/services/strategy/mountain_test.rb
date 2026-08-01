# frozen_string_literal: true

require "test_helper"

class StrategyMountainTest < ActiveSupport::TestCase
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

  test "empty without a goal" do
    mountain = Strategy::Mountain.for(goal: nil)
    assert_equal :empty, mountain[:stage]
    assert_equal 0, mountain[:progress]
  end

  test "stages evolve with the expedition" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Become a Rails developer", position: 0
    )
    assert_equal :foothill, Strategy::Mountain.for(goal: goal.reload)[:stage]

    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Find a job", position: 0
    )
    assert_equal :trail, Strategy::Mountain.for(goal: goal.reload)[:stage]

    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Learn German", position: 0
    )
    other = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Ship portfolio", position: 1
    )
    assert_equal :camp, Strategy::Mountain.for(goal: goal.reload)[:stage]

    project_leaf = practice_leaf_for!(project)
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project_leaf, horizon: "day",
      title: "Learn 20 words", scheduled_on: Date.current, position: 0
    )
    other_leaf = practice_leaf_for!(other)
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: other_leaf, horizon: "day",
      title: "Write README", scheduled_on: Date.current, position: 0
    )

    project.complete!
    Strategy::SyncCompletion.call(project: project)

    mountain = Strategy::Mountain.for(goal: goal.reload)
    assert_equal :flags, mountain[:stage]
    assert_equal 1, mountain[:flags]
    assert_operator mountain[:progress], :<, 100

    other.complete!
    Strategy::SyncCompletion.call(project: other)
    summit = Strategy::Mountain.for(goal: goal.reload)
    assert_equal :summit, summit[:stage]
    assert_equal 100, summit[:progress]
  end
end
