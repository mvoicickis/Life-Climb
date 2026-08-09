# frozen_string_literal: true

require "test_helper"

class HabitsMountainLinkTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    @journey = seed_climb!(@user, today_mission: "Ship auth")
    @other = users(:two)
    @other_journey = seed_climb!(@other, area_key: "self", title: "Other mountain", today_mission: "Walk")
    @user.habits.destroy_all
  end

  test "create and edit habit with journey link persists" do
    assert_difference "Habit.count", 1 do
      post habits_path, params: {
        habit: {
          name: "Morning pages",
          unit: "pages",
          points: 5,
          frequency: "daily",
          active: true,
          show_on_home: true,
          life_journey_id: @journey.id
        }
      }
    end
    habit = @user.habits.find_by!(name: "Morning pages")
    assert_equal @journey.id, habit.life_journey_id

    patch habit_path(habit), params: {
      habit: {
        name: "Morning pages",
        unit: "pages",
        points: 5,
        frequency: "daily",
        active: true,
        show_on_home: true,
        life_journey_id: ""
      }
    }
    assert_redirected_to habits_path
    assert_nil habit.reload.life_journey_id

    patch habit_path(habit), params: {
      habit: {
        name: "Morning pages",
        unit: "pages",
        points: 5,
        frequency: "daily",
        active: true,
        show_on_home: true,
        life_journey_id: @journey.id
      }
    }
    assert_equal @journey.id, habit.reload.life_journey_id
  end

  test "cannot link habit to another users mountain" do
    post habits_path, params: {
      habit: {
        name: "Stolen link",
        unit: "times",
        points: 5,
        frequency: "daily",
        active: true,
        show_on_home: true,
        life_journey_id: @other_journey.id
      }
    }
    assert_response :unprocessable_entity
    assert_nil @user.habits.find_by(name: "Stolen link")
  end

  test "Mountain does not render supporting habits section" do
    @user.habits.create!(
      name: "Linked stretch", unit: "minutes", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", life_journey: @journey
    )

    get life_journey_path(@journey)
    assert_response :success
    assert_select ".lp-rpg-habits", count: 0
    assert_select ".lp-rpg-habits__title", text: /Supporting habits/i, count: 0
  end

  test "Today shows all on_home habits regardless of journey link" do
    linked = @user.habits.create!(
      name: "Linked stretch", unit: "minutes", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", life_journey: @journey
    )
    general = @user.habits.create!(
      name: "General water", unit: "glasses", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth"
    )
    @user.habits.create!(
      name: "Hidden linked", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: false, stat_type: "growth", life_journey: @journey
    )

    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-anytime .lp-dash-tcard__title", text: linked.name
    assert_select ".lp-dash-anytime .lp-dash-tcard__title", text: general.name
    assert_select ".lp-dash-anytime .lp-dash-tcard__title", text: "Hidden linked", count: 0
  end

  test "primary nav includes Habits entry" do
    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-nav__link", text: /Mountain/i
    assert_select ".lp-dash-nav__link", text: /Today/i
    assert_select ".lp-dash-nav__link", text: /Habits/i
    assert_select ".lp-dash-nav__link", text: /Journey/i
    assert_select ".lp-dash-nav__link", text: /You/i
    assert_select ".lp-dash-nav a[href=?]", habits_path

    get habits_path
    assert_response :success
    assert_select ".lp-dash-nav__link.is-active", text: /Habits/i
    assert_select ".lp-habits", minimum: 1
  end
end
