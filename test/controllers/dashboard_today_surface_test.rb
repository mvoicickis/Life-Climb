# frozen_string_literal: true

require "test_helper"

# Guards the shared TodaySurface loader — non-gap Today must keep loading.
class DashboardTodaySurfaceTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(character: "fox")
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Find a job",
      ideal_scene: "Hired",
      current_reality: "Searching",
      today_mission: "Plan the path",
      closer_percent: 10,
      route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    # Easy commitment → no commitment_gap short-circuit.
    @journey.update!(
      commitment_key: "easy",
      commitment_name: "Easy",
      commitment_habit_count: 1,
      commitment_battle_count: 1
    )
    @user.habits.active.on_home.destroy_all
    @user.habits.create!(name: "Water", active: true, show_on_home: true, unit: "times")
  end

  test "non-gap Today loads battle surface wrapper without error" do
    get dashboard_path
    assert_response :success
    assert_select "#today-battle-surface"
    assert_select "#next-action-slot"
    assert_select "[data-next-action-key=commitment_gap]", count: 0
    assert_select ".lp-dash-header, .lp-dash", minimum: 1
  end

  test "Easy with zero habits shows setup_gap not commitment_gap" do
    @user.habits.active.on_home.destroy_all
    @user.daily_todos.create!(
      title: "First fight", scheduled_on: Date.current, aspect_key: "career",
      position: 1
    )

    get dashboard_path
    assert_response :success
    assert_select "[data-next-action-key=commitment_gap]", count: 0
    assert_select "#commitment-gap-panel[data-next-action-key=setup_gap]", count: 1
  end
end
