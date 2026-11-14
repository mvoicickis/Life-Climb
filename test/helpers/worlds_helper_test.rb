# frozen_string_literal: true

require "test_helper"

class WorldsHelperTest < ActionView::TestCase
  test "win_step edges" do
    assert_equal 0, WorldsHelper.win_step(0)
    assert_equal 1, WorldsHelper.win_step(1)
    assert_equal 2, WorldsHelper.win_step(2)
    assert_equal 2, WorldsHelper.win_step(10)
    assert_equal 3, WorldsHelper.win_step(11)
    assert_equal 3, WorldsHelper.win_step(50)
    assert_equal 4, WorldsHelper.win_step(51)
  end

  test "day_cell_step edges" do
    assert_equal 0, WorldsHelper.day_cell_step(0)
    assert_equal 1, WorldsHelper.day_cell_step(1)
    assert_equal 2, WorldsHelper.day_cell_step(2)
    assert_equal 2, WorldsHelper.day_cell_step(3)
    assert_equal 4, WorldsHelper.day_cell_step(4)
  end

  test "my_world_journey_title prefers root goal title" do
    journey = LifeJourney.new(title: "Journey name")
    journey.id = 42
    goal = StrategyGoal.new(title: "Goal name")
    @root_goals_by_journey_id = { 42 => goal }

    assert_equal "Goal name", my_world_journey_title(journey)

    goal.title = "   "
    assert_equal "Journey name", my_world_journey_title(journey)

    @root_goals_by_journey_id = {}
    assert_equal "Journey name", my_world_journey_title(journey)
  end
end
