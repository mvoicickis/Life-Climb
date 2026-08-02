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
    @practice = Strategy::EnsureFolderQuest.call(folder: @camp)
  end

  test "create adds an objective under the folder checklist" do
    assert_difference -> { @practice.practice_tasks.count }, 1 do
      post strategy_goal_practice_tasks_path(@practice), params: { title: "Design layout" }
    end
    assert_redirected_to life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp.id)
    follow_redirect!
    assert_select ".lp-qs-detail.is-open"
    assert_select ".lp-qs-detail__title", text: /Camp/
    assert_select ".lp-qs-obj__text[value='Design layout']"
    assert_select ".lp-qs-detail__add-input"
    assert_select ".lp-rpg-practice-folder__plan-hint", count: 0
    assert_select ".lp-rpg-practice-add", text: /Prepare New Quest/i, count: 0
  end

  test "create with position inserts and shifts siblings" do
    first = @practice.practice_tasks.create!(user: @user, title: "A", position: 0)
    second = @practice.practice_tasks.create!(user: @user, title: "B", position: 1)

    post strategy_goal_practice_tasks_path(@practice),
         params: { title: "Restored", position: 0, completed: "1" }
    assert_response :redirect

    restored = @practice.practice_tasks.find_by!(title: "Restored")
    assert_equal 0, restored.position
    assert restored.completed?
    assert_equal 1, first.reload.position
    assert_equal 2, second.reload.position
  end

  test "update renames an objective title" do
    task = @practice.practice_tasks.create!(user: @user, title: "Old name", position: 0)
    patch practice_task_path(task), params: { title: "New name" }
    assert_redirected_to life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp.id)
    assert_equal "New name", task.reload.title
  end

  test "completing objectives does not auto-complete the host day" do
    first = @practice.practice_tasks.create!(user: @user, title: "Design layout", position: 0)
    second = @practice.practice_tasks.create!(user: @user, title: "Polish header", position: 1)

    patch practice_task_path(first), params: { completed: "1" }
    assert_redirected_to life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp.id)
    assert_not @practice.reload.completed?

    patch practice_task_path(second), params: { completed: "1" }
    follow_redirect!
    assert_not @practice.reload.completed?
    assert_select ".lp-qs-obj__check.is-done", minimum: 2
    assert_select ".lp-rpg-practice-finish__copy", count: 0
  end

  test "destroy removes an objective" do
    task = @practice.practice_tasks.create!(user: @user, title: "Temp", position: 0)
    assert_difference -> { @practice.practice_tasks.count }, -1 do
      delete practice_task_path(task)
    end
    assert_redirected_to life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp.id)
  end
end
