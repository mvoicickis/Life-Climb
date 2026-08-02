# frozen_string_literal: true

require "test_helper"

class PracticeTasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Find a job",
      ideal_scene: "Hired",
      current_reality: "Searching",
      next_win: "Interview",
      today_mission: "Apply",
      closer_percent: 20,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Path", position: 0
    )
    @section = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "MVP", position: 0
    )
    @camp = @section.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Camp", position: 0
    )
    @practice = @camp.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Finish page", scheduled_on: Date.current, position: 0
    )
  end

  test "create adds an objective under a practice" do
    assert_difference -> { @practice.practice_tasks.count }, 1 do
      post strategy_goal_practice_tasks_path(@practice), params: { title: "Design layout" }
    end
    assert_redirected_to life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp.id)
    follow_redirect!
    assert_select ".lp-rpg-practice-folder__title", text: /Finish page/
    assert_select ".lp-rpg-practice-task__title", text: /Design layout/
    assert_select "input.lp-rpg-practice-folder__add-btn[value*='Add New Task']"
  end

  test "completing all tasks shows finish prompt without completing practice" do
    first = @practice.practice_tasks.create!(user: @user, title: "Design layout", position: 0)
    second = @practice.practice_tasks.create!(user: @user, title: "Polish header", position: 1)

    patch practice_task_path(first), params: { completed: "1" }
    assert_redirected_to life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp.id)
    assert_not @practice.reload.completed?

    patch practice_task_path(second), params: { completed: "1" }
    follow_redirect!
    assert_not @practice.reload.completed?
    assert_select ".lp-rpg-practice-finish__copy", text: /All objectives are complete/
    assert_select ".lp-rpg-practice-finish__btn.is-complete", text: /Complete Practice/i
    assert_select ".lp-rpg-practice-finish__btn.is-more", text: /Add More Tasks/i
  end

  test "plan for today stays on the practice folder" do
    @practice.update!(scheduled_on: Date.current + 1.day)
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp.id)
    assert_response :success
    assert_select ".lp-rpg-practice-folder__plan-check:not([checked])"
    assert_select ".lp-rpg-practice-folder__plan-label", text: /Plan for Today/i
  end
end
