# frozen_string_literal: true

require "test_helper"

class HabitProjectLinkTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @area = life_areas(:one_self)
    @habit = habits(:one)
    @goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "Season", position: 0)
    @plan = @user.strategy_goals.create!(
      life_area: @area, parent: @goal, horizon: "plan", title: "Path", position: 0
    )
    @project = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Improve Income", position: 0
    )
  end

  test "path-level project can link many habits via join" do
    other = @user.habits.create!(
      name: "Push-Ups", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth"
    )
    HabitProjectLink.create!(habit: @habit, strategy_goal: @project)
    HabitProjectLink.create!(habit: other, strategy_goal: @project)

    assert_equal 2, @project.linked_habits.count
    assert_includes @habit.improvement_projects, @project
    assert_includes other.improvement_projects, @project
    assert @project.tracker_linked?
  end

  test "rejects link on a day" do
    day = @user.strategy_goals.create!(
      life_area: @area, parent: @project, horizon: "day",
      title: "Battle", scheduled_on: Date.current, position: 0
    )
    link = HabitProjectLink.new(habit: @habit, strategy_goal: day)
    assert_not link.valid?
    assert link.errors[:strategy_goal_id].any?
  end

  test "rejects habit belonging to another user" do
    link = HabitProjectLink.new(habit: habits(:two), strategy_goal: @project)
    assert_not link.valid?
    assert link.errors[:habit_id].any?
  end

  test "backfill-equivalent improve income project keeps habit through join" do
    HabitProjectLink.create!(habit: @habit, strategy_goal: @project)

    assert_equal "Improve Income", @habit.improvement_projects.sole.title
    assert_equal @habit.id, @project.linked_habits.sole.id
  end
end
