# frozen_string_literal: true

require "test_helper"

class HabitQuantityCheckinFormTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "new habit form includes quantity checkin toggle" do
    get new_habit_path
    assert_response :success
    assert_select "input[type=checkbox][name='habit[quantity_checkin]']"
    assert_match(/Log a number each day/i, response.body)
  end

  test "creating with quantity checkin on persists true" do
    assert_difference -> { @user.habits.count }, 1 do
      post habits_path, params: {
        habit: {
          name: "Push-Ups",
          unit: "times",
          quantity_checkin: "1",
          frequency: "daily",
          points: 5,
          stat_type: "growth"
        }
      }
    end

    habit = @user.habits.order(:id).last
    assert_equal "Push-Ups", habit.name
    assert habit.quantity_checkin?
    assert_redirected_to dashboard_path
  end

  test "creating with quantity checkin off persists false" do
    assert_difference -> { @user.habits.count }, 1 do
      post habits_path, params: {
        habit: {
          name: "Meditate",
          unit: "times",
          quantity_checkin: "0",
          frequency: "daily",
          points: 5,
          stat_type: "growth"
        }
      }
    end

    habit = @user.habits.order(:id).last
    assert_not habit.quantity_checkin?
    assert habit.binary_checkin?
  end
end
