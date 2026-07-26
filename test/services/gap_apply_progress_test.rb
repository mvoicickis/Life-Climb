# frozen_string_literal: true

require "test_helper"

class GapApplyProgressTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "Calm productive days",
      current_reality: "Building daily",
      next_win: "Launch Beta",
      today_mission: "Write a test",
      closer_percent: 40
    )
    @journey = @user.reload.primary_focused_journey
    @start_gap = @journey.gap_percent.to_f
  end

  test "todo moves gap only a little and writes snapshot" do
    result = Gap::ApplyProgress.call(journey: @journey, tier: :todo)
    @journey.reload

    assert result[:delta].positive?
    assert_operator result[:delta], :<=, GameRules::TODO_ABS_CAP
    assert_in_delta @start_gap - result[:delta], @journey.gap_percent.to_f, 0.01
    assert @journey.gap_snapshots.exists?(recorded_on: Date.current)
  end

  test "mission moves gap more than one todo" do
    todo_delta = Gap::ApplyProgress.call(journey: @journey, tier: :todo)[:delta]
    @journey.update!(gap_percent: @start_gap)

    mission = @journey.missions.for_day.primary.first
    mission_delta = Gap::ApplyProgress.call(
      journey: @journey,
      tier: :mission,
      raw_basis_points: mission.gap_delta_basis_points
    )[:delta]

    assert_operator mission_delta, :>, todo_delta
  end

  test "five todos move less than one mission from the same start" do
    five_todo_move = 0.0
    gap = @start_gap
    5.times do
      @journey.update!(gap_percent: gap)
      delta = Gap::ApplyProgress.call(journey: @journey.reload, tier: :todo)[:delta]
      five_todo_move += delta
      gap = @journey.reload.gap_percent.to_f
    end

    @journey.update!(gap_percent: @start_gap)
    mission = @journey.missions.for_day.primary.first
    mission_delta = Gap::ApplyProgress.call(
      journey: @journey.reload,
      tier: :mission,
      raw_basis_points: mission.gap_delta_basis_points
    )[:delta]

    assert_operator five_todo_move, :<, mission_delta
  end
end
