# frozen_string_literal: true

require "test_helper"

class DailyTodoVisiblePathProjectTest < ActiveSupport::TestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @journey = seed_climb!(@user, today_mission: "Ship auth")
    @todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Ship auth")
    @project = @todo.strategy_goal.parent
  end

  test "returns the path project for a tagged battle" do
    @project.update!(color_key: "purple")
    assert_equal @project, @todo.visible_path_project
    assert_equal "purple", @todo.visible_path_project.tagged_color_key
  end

  test "returns the path project when it has no colour" do
    @project.update!(color_key: nil)
    assert_equal @project, @todo.visible_path_project
    assert_nil @todo.visible_path_project.tagged_color_key
  end

  test "returns nil for a holding-camp battle" do
    holding = Strategy::HoldingProject.ensure!(user: @user, journey: @journey)
    day = holding.children.create!(
      user: @user,
      life_area: @journey.life_area,
      life_journey: @journey,
      horizon: "day",
      title: "Call the dentist",
      scheduled_on: Date.current,
      position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @journey.life_area)
    todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Call the dentist")

    assert day.parent.holding?
    assert_nil todo.visible_path_project
  end

  test "returns nil when the battle has no parent project" do
    @todo.update!(strategy_goal: nil)
    assert_nil @todo.visible_path_project
  end
end
