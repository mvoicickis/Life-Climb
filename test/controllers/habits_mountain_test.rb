# frozen_string_literal: true

require "test_helper"

class HabitsMountainTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, area_key: "career", title: "Ship LifePoints", today_mission: "Write tests")
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_area(@area.id).for_kind("goal").roots.first
    @plan = @goal.children.find(&:plan?) || @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Main path", position: 0
    )
    @user.habits.destroy_all
  end

  test "mountain create turbo stream refreshes trail-base-sheet with quantity habit" do
    assert_difference "Habit.count", 1 do
      post habits_path, params: mountain_habit_params(
        name: "Read",
        quantity_checkin: "1",
        unit: "pages"
      ), as: :turbo_stream
    end

    assert_response :ok
    assert_includes @response.media_type, "turbo-stream"
    assert_match "trail-base-sheet", response.body
    assert_match "Read", response.body
    assert_match "0 pages", response.body

    habit = @user.habits.find_by!(name: "Read")
    assert habit.quantity_checkin?
    assert_equal "pages", habit.unit
    assert_equal @journey.id, habit.life_journey_id
  end

  test "mountain create without quantity uses times checkin" do
    post habits_path, params: mountain_habit_params(name: "Stretch"), as: :turbo_stream

    assert_response :ok
    habit = @user.habits.find_by!(name: "Stretch")
    assert_not habit.quantity_checkin?
    assert_equal "times", habit.unit
  end

  test "mountain turbo rejects another users journey ids" do
    other = users(:two)
    seed_climb!(other, area_key: "career", title: "Other climb", today_mission: "Other")
    other_goal = other.strategy_goals.for_kind("goal").roots.first
    other_plan = other_goal.children.find(&:plan?)

    post habits_path, params: mountain_habit_params(
      name: "Stolen",
      life_journey_id: other.primary_focused_journey.id,
      goal_id: other_goal.id,
      plan_id: other_plan.id
    ), as: :turbo_stream

    assert_response :redirect
    assert_redirected_to dashboard_path
    assert_nil @user.habits.find_by(name: "Stolen")
  end

  test "mountain turbo rejects mismatched habit life_journey_id" do
    other = users(:two)
    seed_climb!(other, area_key: "career", title: "Other climb", today_mission: "Other")

    post habits_path, params: mountain_habit_params(
      name: "Mismatch",
      habit_life_journey_id: other.primary_focused_journey.id
    ), as: :turbo_stream

    assert_response :redirect
    assert_redirected_to dashboard_path
    assert_nil @user.habits.find_by(name: "Mismatch")
  end

  private

  def mountain_habit_params(name:, quantity_checkin: "0", unit: "times", life_journey_id: nil, goal_id: nil, plan_id: nil, habit_life_journey_id: nil)
    {
      return_to: "mountain",
      life_journey_id: life_journey_id || @journey.id,
      goal_id: goal_id || @goal.id,
      plan_id: plan_id || @plan.id,
      habit: {
        name: name,
        frequency: "daily",
        quantity_checkin: quantity_checkin,
        unit: unit,
        life_journey_id: habit_life_journey_id || @journey.id
      }
    }
  end

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password12345" }
  end
end
