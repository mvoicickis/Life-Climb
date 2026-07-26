# frozen_string_literal: true

require "test_helper"

class ProgressDashboardTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "Calm productive days",
      current_reality: "Building daily",
      next_win: "Launch Beta",
      today_mission: "Finish progress page",
      closer_percent: 40
    )
    @user.reload
  end

  test "aggregates kpis growth and projects for a period" do
    journey = @user.primary_focused_journey
    mission = journey.missions.for_day.primary.first
    Missions::Complete.call(user: @user, mission: mission)

    @user.daily_todos.create!(
      title: "Write tests",
      aspect_key: "career",
      scheduled_on: Date.current,
      completed_at: Time.current,
      lp_reward: 30
    )
    LifePoints::Award.call(
      user: @user,
      amount: 30,
      reason: "Battle win: Write tests",
      source: @user.daily_todos.last
    )

    data = Progress::Dashboard.call(user: @user.reload, period: "7d")

    assert_equal "7d", data[:period].key
    assert_equal 3, data[:kpis].size
    assert data[:growth].any?
    assert data[:projects].any?
    assert_equal "Launch Beta", data[:projects].first[:title]
    assert data[:achievements].any?
    assert data[:insights].any?
    assert data[:heatmap][:cells].any?
    assert_equal 26 * 7, data[:heatmap][:cells].size
    assert data[:heatmap][:month_labels].any?
    assert_equal 3, data[:heatmap][:day_labels].size
    assert_equal 26, data[:heatmap][:weeks]
    assert data[:heatmap][:active_days].is_a?(Integer)
    assert data[:heatmap][:active_days] >= 1
  end

  test "period filter accepts all time" do
    data = Progress::Dashboard.call(user: @user, period: "all")
    assert_equal "all", data[:period].key
  end
end
