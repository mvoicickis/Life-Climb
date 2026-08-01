# frozen_string_literal: true

require "test_helper"

class Strategy::ProgressTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @area = life_areas(:one_self)
  end

  test "percent is zero without plans" do
    goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    assert_equal 0, Strategy::Progress.percent(goal)
  end

  test "battles alone do not move goal percent" do
    goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    plan = @user.strategy_goals.create!(life_area: @area, parent: goal, horizon: "plan", title: "P", position: 0)
    project = @user.strategy_goals.create!(life_area: @area, parent: plan, horizon: "project", title: "Pr", position: 0)
    project_leaf = practice_leaf_for!(project)
    battle = @user.strategy_goals.create!(
      life_area: @area, parent: project_leaf, horizon: "day", title: "A",
      scheduled_on: Date.current, position: 0
    )
    battle.complete!

    assert_equal 0, Strategy::Progress.percent(goal)
    assert_equal 0, Strategy::Progress.percent(plan)
    assert_equal 0, Strategy::Progress.percent(project)
    assert_equal 100, Strategy::Progress.percent(battle)
  end

  test "equal plan weight and project shares" do
    goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    plans = 4.times.map do |i|
      @user.strategy_goals.create!(life_area: @area, parent: goal, horizon: "plan", title: "Plan #{i}", position: i)
    end
    projects = plans.flat_map do |plan|
      5.times.map do |i|
        @user.strategy_goals.create!(
          life_area: @area, parent: plan, horizon: "project", title: "#{plan.title} P#{i}", position: i
        )
      end
    end

    projects.first.complete!
    Strategy::SyncCompletion.call(project: projects.first)

    assert_equal 5, Strategy::Progress.percent(goal.reload)
    assert_equal 20, Strategy::Progress.percent(plans.first.reload)
    assert_equal 0, Strategy::Progress.percent(plans.second.reload)

    plans.first.children.select(&:project?).each do |project|
      project.complete!
      Strategy::SyncCompletion.call(project: project)
    end

    assert_equal 25, Strategy::Progress.percent(goal.reload)
    assert plans.first.reload.completed?
    assert_not goal.reload.completed?
  end

  test "finishing all projects completes the year goal" do
    goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    plan = @user.strategy_goals.create!(life_area: @area, parent: goal, horizon: "plan", title: "P", position: 0)
    project = @user.strategy_goals.create!(life_area: @area, parent: plan, horizon: "project", title: "Pr", position: 0)

    project.complete!
    Strategy::SyncCompletion.call(project: project)

    assert_equal 100, Strategy::Progress.percent(goal.reload)
    assert plan.reload.completed?
    assert goal.reload.completed?
  end

  test "leaf checkpoint percent stays binary and project-gated" do
    goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    plan = @user.strategy_goals.create!(life_area: @area, parent: goal, horizon: "plan", title: "P", position: 0)
    project = @user.strategy_goals.create!(life_area: @area, parent: plan, horizon: "project", title: "Camp", position: 0)
    leaf = practice_leaf_for!(project)
    battle = @user.strategy_goals.create!(
      life_area: @area, parent: leaf, horizon: "day", title: "A",
      scheduled_on: Date.current, position: 0
    )
    battle.complete!

    assert_equal 0, Strategy::Progress.percent(leaf.reload)

    leaf.complete!
    assert_equal 100, Strategy::Progress.percent(leaf.reload)
  end

  test "branch checkpoint percent averages direct children recursively at depth 3+" do
    goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    plan = @user.strategy_goals.create!(life_area: @area, parent: goal, horizon: "plan", title: "P", position: 0)
    root = @user.strategy_goals.create!(life_area: @area, parent: plan, horizon: "project", title: "Root", position: 0)
    left = @user.strategy_goals.create!(life_area: @area, parent: root, horizon: "project", title: "Left", position: 0)
    right = @user.strategy_goals.create!(life_area: @area, parent: root, horizon: "project", title: "Right", position: 1)
    deep_a = @user.strategy_goals.create!(life_area: @area, parent: left, horizon: "project", title: "Deep A", position: 0)
    deep_b = @user.strategy_goals.create!(life_area: @area, parent: left, horizon: "project", title: "Deep B", position: 1)
    # right stays a leaf (no children) — complete it for 100%

    deep_a.complete!
    # left = avg(100, 0) = 50; right = 0; root = avg(50, 0) = 25
    assert_equal 100, Strategy::Progress.percent(deep_a.reload)
    assert_equal 0, Strategy::Progress.percent(deep_b.reload)
    assert_equal 50, Strategy::Progress.percent(left.reload)
    assert_equal 0, Strategy::Progress.percent(right.reload)
    assert_equal 25, Strategy::Progress.percent(root.reload)

    right.complete!
    # left = 50; right = 100; root = avg(50, 100) = 75
    assert_equal 75, Strategy::Progress.percent(root.reload)

    deep_b.complete!
    # left = 100; right = 100; root = 100
    assert_equal 100, Strategy::Progress.percent(left.reload)
    assert_equal 100, Strategy::Progress.percent(root.reload)
  end

  test "plan percent averages nested branch project percents not flattened leaves" do
    goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    plan = @user.strategy_goals.create!(life_area: @area, parent: goal, horizon: "plan", title: "P", position: 0)
    branch = @user.strategy_goals.create!(life_area: @area, parent: plan, horizon: "project", title: "Branch", position: 0)
    leaf = @user.strategy_goals.create!(life_area: @area, parent: plan, horizon: "project", title: "Leaf", position: 1)
    child_a = @user.strategy_goals.create!(life_area: @area, parent: branch, horizon: "project", title: "A", position: 0)
    child_b = @user.strategy_goals.create!(life_area: @area, parent: branch, horizon: "project", title: "B", position: 1)

    child_a.complete!
    # If flattened wrongly: 3 leaves with 1 done → 33. Nested: branch=50, leaf=0 → plan=25
    assert_equal 50, Strategy::Progress.percent(branch.reload)
    assert_equal 25, Strategy::Progress.percent(plan.reload)
  end
end

