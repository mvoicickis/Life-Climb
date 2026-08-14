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

  test "plan percent averages sibling path camps" do
    goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    plan = @user.strategy_goals.create!(life_area: @area, parent: goal, horizon: "plan", title: "P", position: 0)
    camp_a = @user.strategy_goals.create!(life_area: @area, parent: plan, horizon: "project", title: "A", position: 0)
    camp_b = @user.strategy_goals.create!(life_area: @area, parent: plan, horizon: "project", title: "B", position: 1)

    camp_a.complete!
    assert_equal 100, Strategy::Progress.percent(camp_a.reload)
    assert_equal 0, Strategy::Progress.percent(camp_b.reload)
    assert_equal 50, Strategy::Progress.percent(plan.reload)

    camp_b.complete!
    assert_equal 100, Strategy::Progress.percent(plan.reload)
  end

  test "quantified path-level project percent uses amount over target" do
    goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    plan = @user.strategy_goals.create!(life_area: @area, parent: goal, horizon: "plan", title: "P", position: 0)
    project = @user.strategy_goals.create!(
      life_area: @area, parent: plan, horizon: "project", title: "Book",
      position: 0, target_amount: 700, unit: "pages", current_amount: 70
    )
    leaf = practice_leaf_for!(project)
    assert_equal 10, Strategy::Progress.percent(leaf)
    assert_equal 10, Strategy::Progress.percent(project)
    assert_equal 10, Strategy::Progress.percent(plan)

    project.update!(current_amount: 700)
    assert_equal 100, Strategy::Progress.percent(project.reload)
  end
end
