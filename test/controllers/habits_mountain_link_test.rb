# frozen_string_literal: true

require "test_helper"

class HabitsMountainLinkTest < ActionDispatch::IntegrationTest
  setup { enable_habits! }
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

  test "Today V2 shows on_home habits on the battlefield surface" do
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
    assert_select ".lp-dash-anytime", count: 1
    assert_select "#today_habit_#{linked.id}", count: 1
    assert_select "#today_habit_#{general.id}", count: 1
    assert_today_v2_shell!
  end

  test "Mountain base camp shows the same Basics after Focus::SetJourneys switch" do
    first = @journey
    second = create_second_journey!(title: "Second mountain", area_key: "self")
    assert_not_equal first.id, second.id

    linked_first = @user.habits.create!(
      name: "Linked to first", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", life_journey: first
    )
    linked_second = @user.habits.create!(
      name: "Linked to second", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", life_journey: second
    )
    general = @user.habits.create!(
      name: "General water", unit: "glasses", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth"
    )
    hidden = @user.habits.create!(
      name: "Hidden off home", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: false, stat_type: "growth", life_journey: first
    )

    Focus::SetJourneys.call(user: @user, journey_ids: [ first.id ])
    get life_journey_path(first)
    assert_response :success
    assert_select "#trail-base-habit-#{linked_first.id}"
    assert_select "#trail-base-habit-#{linked_second.id}"
    assert_select "#trail-base-habit-#{general.id}"
    assert_select "#trail-base-habit-#{hidden.id}", count: 0

    Focus::SetJourneys.call(user: @user, journey_ids: [ second.id ])
    get life_journey_path(second)
    assert_response :success
    assert_select "#trail-base-habit-#{linked_first.id}"
    assert_select "#trail-base-habit-#{linked_second.id}"
    assert_select "#trail-base-habit-#{general.id}"
    assert_select "#trail-base-habit-#{hidden.id}", count: 0
  end

  test "primary nav includes shared v4 tab bar on Today" do
    get dashboard_path
    assert_response :success
    assert_select "#today-dash-nav .lp-dash-nav.is-v4"
    assert_select ".lp-dash-nav__link", text: /Mountain/i
    assert_select ".lp-dash-nav__link", text: /Today/i
    assert_select ".lp-dash-nav__link", text: /You/i
    assert_select ".lp-dash-nav__link", text: /Habits/i, count: 0
    assert_select ".lp-dash-nav__link", text: /Stats/i, count: 1
    assert_select ".lp-dash-nav a[href=?]", habits_path, count: 0

    get habits_path
    assert_response :success
    assert_select ".lp-habits", minimum: 1
    assert_select ".lp-dash-nav__link.is-active", text: /Habits/i, count: 0
  end

  def create_second_journey!(title:, area_key:)
    LifeAreas::Select.call(user: @user, keys: [ area_key ])
    area = @user.life_areas.v2_selected.find_by!(key: area_key)
    journey = Journeys::Create.call(
      user: @user,
      life_area: area,
      title: title,
      ideal_scene: "Ideal #{title}",
      current_reality: "Present #{title}",
      next_win: "Next #{title}",
      closer_percent: 20
    )
    goal = @user.strategy_goals.create!(
      user: @user,
      life_area: area,
      life_journey: journey,
      horizon: "goal",
      title: title,
      position: 0
    )
    plan = goal.children.create!(
      user: @user, life_area: area, life_journey: journey,
      horizon: "plan", title: "Plan #{title}", position: 0
    )
    project = plan.children.create!(
      user: @user, life_area: area, life_journey: journey,
      horizon: "project", title: "Camp #{title}", position: 0
    )
    project.children.create!(
      user: @user, life_area: area, life_journey: journey,
      horizon: "day", title: "Walk", scheduled_on: Date.current, position: 0
    )
    journey
  end
end
