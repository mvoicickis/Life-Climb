# frozen_string_literal: true

require "test_helper"

class Strategy::SyncCompletionTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @area = life_areas(:one_self)
    allow_extra_climbs!(@user)
  end

  test "adding a project to a complete plan drops percent and reopens plan and goal" do
    goal, plan, = complete_two_project_spine!

    assert plan.reload.completed?
    assert goal.reload.completed?
    assert_equal 100, Strategy::Progress.percent(plan)

    third = @user.strategy_goals.create!(
      life_area: @area, parent: plan, horizon: "project", title: "Extra work", position: 2
    )
    Strategy::SyncCompletion.resync!(node: third)

    assert_equal 67, Strategy::Progress.percent(plan.reload)
    assert_not plan.completed?
    assert_equal 67, Strategy::Progress.percent(goal.reload)
    assert_not goal.completed?
  end

  test "adding a plan under a complete goal reopens the goal" do
    goal, = complete_two_project_spine!

    assert goal.reload.completed?
    assert_equal 100, Strategy::Progress.percent(goal)

    new_plan = @user.strategy_goals.create!(
      life_area: @area, parent: goal, horizon: "plan", title: "Second path", position: 1
    )
    Strategy::SyncCompletion.resync!(node: new_plan)

    assert_equal 50, Strategy::Progress.percent(goal.reload)
    assert_not goal.completed?
  end

  test "adding a sibling path project under a complete plan reopens plan and goal" do
    goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    plan = @user.strategy_goals.create!(life_area: @area, parent: goal, horizon: "plan", title: "P", position: 0)
    path = @user.strategy_goals.create!(life_area: @area, parent: plan, horizon: "project", title: "Camp", position: 0)
    path.complete!
    Strategy::SyncCompletion.call(project: path)

    assert path.reload.completed?
    assert plan.reload.completed?

    extra = @user.strategy_goals.create!(
      life_area: @area, parent: plan, horizon: "project", title: "Extra camp", position: 1
    )
    Strategy::SyncCompletion.resync!(node: extra)

    assert_not plan.reload.completed?
    assert_not goal.reload.completed?
  end

  test "raising quantified target above current amount reopens project plan and goal" do
    goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    plan = @user.strategy_goals.create!(life_area: @area, parent: goal, horizon: "plan", title: "P", position: 0)
    project = @user.strategy_goals.create!(
      life_area: @area, parent: plan, horizon: "project", title: "Revenue",
      position: 0, target_amount: 100, unit: "€", current_amount: 100
    )
    project.complete!
    Strategy::SyncCompletion.call(project: project)

    assert project.reload.completed?
    assert plan.reload.completed?
    assert goal.reload.completed?
    assert_equal 100, Strategy::Progress.percent(project)

    project.update!(target_amount: 200)
    Strategy::SyncCompletion.resync!(node: project)

    assert_equal 50, Strategy::Progress.percent(project.reload)
    assert_not project.completed?
    assert_not plan.reload.completed?
    assert_not goal.reload.completed?
  end

  test "destroying a completed project re-completes ancestors when siblings stay done" do
    goal, plan, projects = complete_two_project_spine!
    keep, drop = projects

    drop.destroy!
    Strategy::SyncCompletion.resync!(node: plan)

    assert keep.reload.completed?
    assert_equal 100, Strategy::Progress.percent(plan.reload)
    assert plan.completed?
    assert goal.reload.completed?
  end

  test "destroying a completed project leaves ancestors open when a sibling is incomplete" do
    goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    plan = @user.strategy_goals.create!(life_area: @area, parent: goal, horizon: "plan", title: "P", position: 0)
    done = @user.strategy_goals.create!(life_area: @area, parent: plan, horizon: "project", title: "A", position: 0)
    open = @user.strategy_goals.create!(life_area: @area, parent: plan, horizon: "project", title: "B", position: 1)
    done.complete!
    Strategy::SyncCompletion.call(project: done)

    assert_not plan.reload.completed?
    assert_equal 50, Strategy::Progress.percent(plan)

    done.destroy!
    Strategy::SyncCompletion.resync!(node: plan)

    assert open.reload.persisted?
    assert_equal 0, Strategy::Progress.percent(plan.reload)
    assert_not plan.completed?
    assert_not goal.reload.completed?
  end

  test "sticky manual project complete survives resync when percent is below 100" do
    goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    plan = @user.strategy_goals.create!(life_area: @area, parent: goal, horizon: "plan", title: "P", position: 0)
    # Quantified path project: complete stamp does not force Progress % to 100.
    project = @user.strategy_goals.create!(
      life_area: @area, parent: plan, horizon: "project", title: "Revenue",
      position: 0, target_amount: 100, unit: "€", current_amount: 40
    )
    open = @user.strategy_goals.create!(life_area: @area, parent: plan, horizon: "project", title: "B", position: 1)

    project.manually_complete!
    assert_equal 40, Strategy::Progress.percent(project.reload)

    Strategy::SyncCompletion.resync!(node: open)

    assert project.reload.manually_completed?
    assert project.completed?
    assert_equal 40, Strategy::Progress.percent(project)
  end

  test "sticky children satisfy plan auto-complete without sticky on the plan" do
    goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    plan = @user.strategy_goals.create!(life_area: @area, parent: goal, horizon: "plan", title: "P", position: 0)
    a = @user.strategy_goals.create!(life_area: @area, parent: plan, horizon: "project", title: "A", position: 0)
    b = @user.strategy_goals.create!(life_area: @area, parent: plan, horizon: "project", title: "B", position: 1)

    a.manually_complete!
    b.manually_complete!
    Strategy::SyncCompletion.resync!(node: b)

    assert plan.reload.completed?
    assert_nil plan.manually_completed_at
  end

  test "companion guide create_project reopens an already-complete plan" do
    journey = @user.life_journeys.create!(
      life_area: @area,
      title: "Career climb",
      ideal_scene: "Hired",
      current_reality: "Searching",
      status: "active"
    )
    goal, plan, = complete_two_project_spine!
    assert plan.reload.completed?

    cursor = {
      "goal_id" => goal.id,
      "plan_id" => plan.id,
      "project_count" => 2,
      "step_count" => 0,
      "status" => "in_progress",
      "template_id" => "create_project"
    }

    updated = Strategy::CompanionGuide::Writer.call(
      user: @user,
      journey: journey,
      kind: "create_project",
      value: "Scope discovery",
      cursor: cursor
    )

    assert_not plan.reload.completed?
    assert_equal 67, Strategy::Progress.percent(plan)
    assert_equal "Scope discovery", @user.strategy_goals.find(updated["project_id"]).title
  end

  private

  def complete_two_project_spine!
    goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    plan = @user.strategy_goals.create!(life_area: @area, parent: goal, horizon: "plan", title: "P", position: 0)
    projects = 2.times.map do |i|
      @user.strategy_goals.create!(
        life_area: @area, parent: plan, horizon: "project", title: "Project #{i}", position: i
      )
    end
    projects.each do |project|
      project.complete!
      Strategy::SyncCompletion.call(project: project)
    end
    [ goal, plan, projects ]
  end
end
