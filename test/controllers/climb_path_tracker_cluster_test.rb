# frozen_string_literal: true

require "test_helper"

class ClimbPathTrackerClusterTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    @journey = seed_climb!(@user, today_mission: "Ship auth")
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.find(&:plan?)
    @planned = @plan.children.find(&:project?)
    @user.habits.destroy_all
  end

  test "planned-only journey keeps Project Sections kicker without trackers cluster" do
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @planned.id)
    assert_response :success
    assert_select ".lp-climb-path__kicker", text: /Project Sections/i
    assert_select ".lp-climb-path__from-trackers", count: 0
    assert_select ".lp-climb-path__node.is-tracker", count: 0
    assert_select ".lp-climb-path__badge", text: "1"
  end

  test "mixed journey splits planned path and compact tracker projects" do
    habit = @user.habits.create!(
      name: "Income", unit: "€", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth"
    )
    improve = @user.strategy_goals.create!(
      life_area: @journey.life_area, life_journey: @journey, parent: @plan,
      horizon: "project", title: "Improve Income", position: 1
    )
    HabitProjectLink.create!(habit: habit, strategy_goal: improve)

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @planned.id)
    assert_response :success
    assert_select ".lp-climb-path__kicker", text: /Your path/i
    assert_select ".lp-climb-path__from-trackers .lp-climb-path__kicker", text: /From your trackers/i
    assert_select ".lp-climb-path__list .lp-climb-path__title", text: @planned.title
    assert_select ".lp-climb-path__list .lp-climb-path__title", text: /Improve Income/, count: 0
    assert_select ".lp-climb-path__node.is-tracker .lp-climb-path__title", text: /Improve Income/
    assert_select ".lp-climb-path__node.is-tracker .lp-climb-path__badge", count: 0
    assert_select ".lp-climb-path__node.is-tracker .lp-climb-path__quests", count: 0
    assert_select ".lp-climb-path__node.is-tracker .lp-climb-path__new-quest", count: 0
  end

  test "focusing a tracker-born project still opens the trackers sheet" do
    habit = @user.habits.create!(
      name: "Income", unit: "€", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth"
    )
    improve = @user.strategy_goals.create!(
      life_area: @journey.life_area, life_journey: @journey, parent: @plan,
      horizon: "project", title: "Improve Income", position: 1
    )
    HabitProjectLink.create!(habit: habit, strategy_goal: improve)

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: improve.id)
    assert_response :success
    assert_select "#project-trackers-#{improve.id}"
    assert_select ".lp-project-trackers__name", text: /Income/
  end
end
