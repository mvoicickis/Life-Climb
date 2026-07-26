# frozen_string_literal: true

require "test_helper"

class Strategy::ProgressTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @area = life_areas(:one_self)
  end

  test "percent is zero without battles" do
    goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    assert_equal 0, Strategy::Progress.percent(goal)
  end

  test "percent counts completed descendant battles" do
    goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    plan = @user.strategy_goals.create!(life_area: @area, parent: goal, horizon: "plan", title: "P", position: 0)
    project = @user.strategy_goals.create!(life_area: @area, parent: plan, horizon: "project", title: "Pr", position: 0)
    month = @user.strategy_goals.create!(
      life_area: @area, parent: project, horizon: "month", title: "M",
      due_on: Date.current.end_of_month, position: 0
    )
    a = @user.strategy_goals.create!(
      life_area: @area, parent: month, horizon: "day", title: "A",
      scheduled_on: Date.current, position: 0
    )
    @user.strategy_goals.create!(
      life_area: @area, parent: month, horizon: "day", title: "B",
      scheduled_on: Date.current, position: 1
    )
    a.complete!
    assert_equal 50, Strategy::Progress.percent(goal)
    assert_equal 50, Strategy::Progress.percent(project)
  end
end
