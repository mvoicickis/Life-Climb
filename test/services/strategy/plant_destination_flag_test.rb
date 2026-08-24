# frozen_string_literal: true

require "test_helper"

class StrategyPlantDestinationFlagTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Become a licensed plumber",
      ideal_scene: "Own my van",
      current_reality: "Day job",
      next_win: "Pass exam",
      today_mission: "Study",
      closer_percent: 5,
      route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
  end

  test "plants destination title and scaffolds default plan only" do
    result = Strategy::PlantDestinationFlag.call(
      user: @user,
      journey: @journey,
      goal: @goal,
      title: "Debt-free and running 10k"
    )

    assert result.created?
    assert_equal "Debt-free and running 10k", @goal.reload.title
    assert_equal 1, @goal.children.for_kind("plan").not_holding.count
    assert_equal 0, @goal.descendant_battles.count
  end

  test "is idempotent when plan already exists" do
    Strategy::PlantDestinationFlag.call(
      user: @user, journey: @journey, goal: @goal, title: "First title"
    )
    assert_no_difference -> { @user.strategy_goals.for_kind("plan").count } do
      result = Strategy::PlantDestinationFlag.call(
        user: @user, journey: @journey, goal: @goal, title: "Updated title"
      )
      assert_not result.created?
    end
    assert_equal "Updated title", @goal.reload.title
  end
end
