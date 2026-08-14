# frozen_string_literal: true

require "test_helper"

class HabitIdentityLabelTest < ActionDispatch::IntegrationTest
  setup { enable_habits! }
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
    @user.habits.destroy_all
  end

  test "identity_label saves and displays on Habits and Today when set" do
    assert_difference "Habit.count", 1 do
      post habits_path, params: {
        habit: {
          name: "Read",
          unit: "pages",
          points: 5,
          frequency: "daily",
          active: true,
          show_on_home: true,
          identity_label: "I am a reader"
        }
      }
    end

    habit = @user.habits.find_by!(name: "Read")
    assert_equal "I am a reader", habit.identity_label

    get habits_path
    assert_response :success
    assert_select ".lp-habit-identity", text: "I am a reader"
    assert_select ".lp-habits__name", text: "Read"

    get habit_path(habit)
    assert_response :success
    assert_select ".lp-habit-identity", text: "I am a reader"
    assert_select ".lp-habits__detail-title", text: "Read"

    get dashboard_path
    assert_response :success
    assert_select "#today_habit_#{habit.id} .lp-habit-identity", text: "I am a reader"
    assert_select "#today_habit_#{habit.id} .lp-dash-tcard__title", text: "Read"

    get new_habit_path
    assert_response :success
    assert_select "label[for=habit_identity_label]", text: /kind of person/i
    assert_select "input[name='habit[identity_label]'][placeholder=?]", "I am a reader"
  end

  test "habits without identity_label render unchanged" do
    habit = @user.habits.create!(
      name: "Meditate", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth"
    )
    assert_nil habit.identity_label

    get habits_path
    assert_response :success
    assert_select ".lp-habits__name", text: "Meditate"
    assert_select ".lp-habit-identity", count: 0

    get dashboard_path
    assert_response :success
    assert_select "#today_habit_#{habit.id} .lp-dash-tcard__title", text: "Meditate"
    assert_select "#today_habit_#{habit.id} .lp-habit-identity", count: 0
  end

  test "blank identity_label normalizes to nil on update" do
    habit = @user.habits.create!(
      name: "Read", unit: "pages", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth",
      identity_label: "I am a reader"
    )

    patch habit_path(habit), params: {
      habit: {
        name: "Read",
        unit: "pages",
        points: 5,
        frequency: "daily",
        active: true,
        show_on_home: true,
        identity_label: "   "
      }
    }
    assert_redirected_to habits_path
    assert_nil habit.reload.identity_label
  end
end
