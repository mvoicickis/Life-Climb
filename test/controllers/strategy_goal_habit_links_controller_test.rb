# frozen_string_literal: true

require "test_helper"

class StrategyGoalHabitLinksControllerTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    @journey = seed_climb!(@user, today_mission: "Ship auth")
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.find(&:plan?)
    @project = @plan.children.find(&:project?)
    @user.habits.destroy_all
    @linked = @user.habits.create!(
      name: "Income", unit: "€", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth"
    )
    HabitProjectLink.create!(habit: @linked, strategy_goal: @project)
    @unlinked = @user.habits.create!(
      name: "Push-Ups", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth"
    )
  end

  test "linked trackers stay off the closed Mountain card" do
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @project.id)
    assert_response :success
    assert_select "#climb-path-project-#{@project.id} .lp-climb-path__title"
    assert_select "#project-trackers-#{@project.id}", count: 0
    assert_select ".lp-project-trackers__add-btn", count: 0
  end

  test "project without linked trackers has no trackers sheet" do
    HabitProjectLink.where(strategy_goal_id: @project.id).delete_all
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @project.id)
    assert_response :success
    assert_select "#project-trackers-#{@project.id}", count: 0
  end

  test "links an existing unlinked tracker to the project" do
    assert_difference -> { HabitProjectLink.where(strategy_goal_id: @project.id).count }, 1 do
      post strategy_goal_habit_links_path(@project), params: { habit_id: @unlinked.id }
    end
    assert_redirected_to life_journey_path(@journey, focus_id: @project.id, sheet: "trackers")
    assert_includes @project.reload.linked_habits, @unlinked
  end

  test "creates a new tracker and links it" do
    assert_difference -> { @user.habits.count }, 1 do
      assert_difference -> { HabitProjectLink.where(strategy_goal_id: @project.id).count }, 1 do
        post strategy_goal_habit_links_path(@project), params: { name: "Sleep", unit: "hours" }
      end
    end
    created = @user.habits.find_by!(name: "Sleep")
    assert_equal "hours", created.unit
    assert_includes @project.reload.linked_habits, created
    assert_redirected_to life_journey_path(@journey, focus_id: @project.id, sheet: "trackers")
  end

  test "Mountain no longer opens a trackers sheet from focus" do
    HabitProjectLink.create!(habit: @unlinked, strategy_goal: @project)
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @project.id, sheet: "trackers")
    assert_response :success
    assert_select "#climb-path-project-#{@project.id}"
    assert_select ".lp-project-trackers__card", count: 0
    assert_select "#project-trackers-#{@project.id}", count: 0
  end
end
