# frozen_string_literal: true

require "test_helper"

class Strategy::CollapseMonthsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @area = life_areas(:one_self)
  end

  test "reparents battles from month under project" do
    goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    plan = @user.strategy_goals.create!(life_area: @area, parent: goal, horizon: "plan", title: "P", position: 0)
    project = @user.strategy_goals.create!(life_area: @area, parent: plan, horizon: "project", title: "Pr", position: 0)
    month = StrategyGoal.new(
      user: @user, life_area: @area, parent: project, horizon: "month",
      title: "July", due_on: Date.current.end_of_month, position: 0
    )
    month.save(validate: false)
    battle = StrategyGoal.new(
      user: @user, life_area: @area, parent: month, horizon: "day",
      title: "Lesson", scheduled_on: Date.current, position: 0
    )
    battle.save(validate: false)

    Strategy::CollapseMonths.call

    assert_equal project.id, battle.reload.parent_id
    assert_not StrategyGoal.exists?(month.id)
  end

  test "creates project when month hung under plan" do
    goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    plan = @user.strategy_goals.create!(life_area: @area, parent: goal, horizon: "plan", title: "Find a job", position: 0)
    month = StrategyGoal.new(
      user: @user, life_area: @area, parent: plan, horizon: "month",
      title: "Get good German", due_on: Date.current.end_of_month, position: 0
    )
    month.save(validate: false)
    battle = StrategyGoal.new(
      user: @user, life_area: @area, parent: month, horizon: "day",
      title: "Lesson 12", scheduled_on: Date.current, position: 0
    )
    battle.save(validate: false)

    Strategy::CollapseMonths.call

    project = plan.children.for_kind("project").find_by(title: "Get good German")
    assert project
    assert_equal project.id, battle.reload.parent_id
    assert_not StrategyGoal.exists?(month.id)
  end
end
