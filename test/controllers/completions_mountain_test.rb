# frozen_string_literal: true

require "test_helper"

class CompletionsMountainTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @user.update_columns(developer: true)
    sign_in_as @user
    seed_climb!(@user, area_key: "career", title: "Ship LifePoints", today_mission: "Write tests")
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_area(@area.id).for_kind("goal").roots.first
    @plan = @goal.children.find(&:plan?) || @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Main path", position: 0
    )
    @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Base camp", position: 0,
      trail_x: 0.48, trail_y: 0.72, color_key: "teal"
    )
    @user.habits.destroy_all
    @habit = @user.habits.create!(
      name: "Meditate",
      unit: "times",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: false,
      stat_type: "growth",
      quantity_checkin: false,
      life_journey_id: @journey.id
    )
  end

  test "mountain tick turbo stream refreshes trail-base-sheet" do
    post completions_path(habit_id: @habit.id), params: mountain_completion_params, as: :turbo_stream

    assert_response :ok
    assert_includes @response.media_type, "turbo-stream"
    assert_match "trail-base-sheet", response.body
    assert_match "Meditate", response.body
    assert @habit.reload.completed_today?
  end

  test "mountain untick turbo stream refreshes trail-base-sheet" do
    completion = @user.completions.create!(habit: @habit, completed_on: Date.current)

    delete completion_path(completion), params: mountain_completion_params, as: :turbo_stream

    assert_response :ok
    assert_includes @response.media_type, "turbo-stream"
    assert_match "trail-base-sheet", response.body
    assert_not @habit.reload.completed_today?
  end

  test "mountain tick rejects another users journey ids" do
    other = users(:two)
    sign_in_as other
    seed_climb!(other, area_key: "career", title: "Other climb", today_mission: "Other")
    other.habits.destroy_all
    habit = other.habits.create!(
      name: "Other meditate",
      unit: "times",
      points: 5,
      frequency: "daily",
      active: true,
      stat_type: "growth",
      quantity_checkin: false
    )

    post completions_path(habit_id: habit.id), params: mountain_completion_params, as: :turbo_stream

    assert_response :redirect
    assert_redirected_to dashboard_path
    assert_not habit.reload.completed_today?
  end

  private

  def mountain_completion_params
    {
      return_to: "mountain",
      life_journey_id: @journey.id,
      goal_id: @goal.id,
      plan_id: @plan.id
    }
  end

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password12345" }
  end
end
