# frozen_string_literal: true

require "test_helper"

class HabitImprovementProjectsControllerTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    @journey = seed_climb!(@user, area_key: "money", title: "Financial freedom", today_mission: "Track spending")
    @habit = habits(:one)
    @area = @user.areas.create!(name: "Finance")
    @habit.update!(area: @area, state: "attention", life_journey: @journey)
  end

  test "creates path-level project linked to habit on attention" do
    assert_difference -> { @user.strategy_goals.for_kind("project").count }, 1 do
      post habit_improvement_projects_path(@habit)
    end
    project = @user.strategy_goals.for_kind("project").order(:id).last
    assert_equal @habit.id, project.habit_id
    assert project.path_level_camp?
    assert_equal @journey.id, project.life_journey_id
    assert_redirected_to life_journey_path(@journey, focus_id: project.id)
  end

  test "uses primary journey when habit has no mountain link" do
    @habit.update!(life_journey: nil)
    post habit_improvement_projects_path(@habit)
    project = @user.strategy_goals.for_kind("project").order(:id).last
    assert_equal @journey.id, project.life_journey_id
  end

  test "requires attention state" do
    @habit.update!(state: "good")
    assert_no_difference -> { @user.strategy_goals.for_kind("project").count } do
      post habit_improvement_projects_path(@habit)
    end
    assert_redirected_to habit_path(@habit)
  end
end
