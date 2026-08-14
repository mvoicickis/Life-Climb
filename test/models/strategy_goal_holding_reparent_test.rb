# frozen_string_literal: true

require "test_helper"

class StrategyGoalHoldingReparentTest < ActiveSupport::TestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @journey = seed_climb!(@user, today_mission: "Ship auth")
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.for_kind("plan").not_holding.ordered.first
    @project = @plan.children.for_kind("project").not_holding.ordered.first
  end

  test "destroying a path project keeps a completed battle on holding" do
    day = @project.children.for_kind("day").ordered.first
    day.update!(completed_at: Time.current)
    day_id = day.id

    points_before = @user.reload.total_points
    @project.destroy!

    kept = StrategyGoal.find(day_id)
    holding = Strategy::HoldingProject.ensure!(user: @user, journey: @journey)
    assert kept.completed?
    assert_equal holding.id, kept.parent_id
    assert_equal points_before, @user.reload.total_points
  end

  test "destroying a user Plan does not wipe holding battles" do
    camp = Strategy::HoldingProject.ensure!(user: @user, journey: @journey)
    loose = camp.children.create!(
      user: @user,
      life_area: @area,
      life_journey: @journey,
      horizon: "day",
      title: "Loose fight",
      scheduled_on: Date.current,
      position: 0,
      completed_at: Time.current
    )
    loose_id = loose.id

    @plan.destroy!

    assert StrategyGoal.exists?(loose_id)
    assert_equal camp.id, StrategyGoal.find(loose_id).parent_id
  end

  test "destroying a Goal wipes holding battles (documented leftover)" do
    camp = Strategy::HoldingProject.ensure!(user: @user, journey: @journey)
    loose = camp.children.create!(
      user: @user,
      life_area: @area,
      life_journey: @journey,
      horizon: "day",
      title: "Loose fight",
      scheduled_on: Date.current,
      position: 0,
      completed_at: Time.current
    )
    loose_id = loose.id

    @goal.destroy!

    assert_not StrategyGoal.exists?(loose_id)
    assert_not StrategyGoal.exists?(camp.id)
  end

  test "goal percent ignores a holding plan" do
    before = Strategy::Progress.percent(@goal)
    Strategy::HoldingProject.ensure!(user: @user, journey: @journey)
    assert_equal before, Strategy::Progress.percent(@goal.reload)
  end

  test "user cannot destroy the holding camp" do
    camp = Strategy::HoldingProject.ensure!(user: @user, journey: @journey)
    refute camp.destroy
    assert StrategyGoal.exists?(camp.id)
  end
end
