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
    assert_select ".lp-climb-path__node.is-selected .lp-climb-path__quests[open]"
    assert_select ".lp-climb-path__quest-title", text: /Camp/
    assert_select ".lp-qs-obj__text[value='Design layout']"
    assert_select ".lp-climb-path__quest-add-input"
    assert_select ".lp-climb-path__quest-add-btn", text: /\AAdd\z/
    assert_select ".lp-rpg-practice-folder__plan-hint", count: 0
    assert_select ".lp-rpg-practice-add", text: /Prepare New Quest/i, count: 0
  end

  test "create responds with turbo stream updating folder objectives" do
    assert_difference -> { @practice.practice_tasks.count }, 1 do
      post strategy_goal_practice_tasks_path(@practice),
           params: { title: "Stream layout" },
           as: :turbo_stream
    end
    assert_equal Mime[:turbo_stream].to_s, response.media_type
    assert_includes response.body, "quest_objectives_#{@camp.id}"
    assert_includes response.body, "quest_progress_#{@camp.id}"
    assert_includes response.body, "Stream layout"
  end

  test "quest detail checkboxes are status-only without complete action" do
    task = @practice.practice_tasks.create!(user: @user, title: "Design layout", position: 0)

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp.id)
    assert_response :success
    assert_select "button.lp-qs-obj__check", count: 0
    assert_select "span.lp-qs-obj__check[aria-label=?]", "Design layout — not done yet"
    assert_select ".lp-qs-obj__check[data-action]", count: 0
    assert_select ".lp-climb-path__quest-add-btn"
    assert_select "turbo-frame#quest_objectives_#{@camp.id}"
    assert_select "#quest_progress_#{@camp.id}"

    task.complete!
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp.id)
    assert_select "span.lp-qs-obj__check.is-done[aria-label=?]", "Design layout — done"
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

  test "update title responds with turbo stream" do
    task = @practice.practice_tasks.create!(user: @user, title: "Old name", position: 0)
    patch practice_task_path(task), params: { title: "Stream name" }, as: :turbo_stream
    assert_equal Mime[:turbo_stream].to_s, response.media_type
    assert_includes response.body, "quest_objectives_#{@camp.id}"
    assert_includes response.body, "Stream name"
    refute_includes response.body, "quest_progress_#{@camp.id}"
    assert_equal "Stream name", task.reload.title
  end

  test "completing the last objective on Today finishes the host day" do
    first = @practice.practice_tasks.create!(user: @user, title: "Design layout", position: 0)
    second = @practice.practice_tasks.create!(user: @user, title: "Polish header", position: 1)
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    todo = @user.daily_todos.for_day(Date.current).find_by!(strategy_goal_id: @practice.id)

    patch practice_task_path(first), params: { completed: "1" }
    assert_redirected_to dashboard_path
    assert_not @practice.reload.completed?
    assert_not todo.reload.completed?

    patch practice_task_path(second), params: { completed: "1" }
    assert_redirected_to dashboard_path
    assert @practice.reload.completed?
    assert todo.reload.completed?
  end

  test "destroy removes an objective" do
    task = @practice.practice_tasks.create!(user: @user, title: "Temp", position: 0)
    assert_difference -> { @practice.practice_tasks.count }, -1 do
      delete practice_task_path(task)
    end
    assert_redirected_to life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp.id)
  end

  test "destroy responds with turbo stream updating folder objectives" do
    task = @practice.practice_tasks.create!(user: @user, title: "Temp stream", position: 0)
    assert_difference -> { @practice.practice_tasks.count }, -1 do
      delete practice_task_path(task), as: :turbo_stream
    end
    assert_equal Mime[:turbo_stream].to_s, response.media_type
    assert_includes response.body, "quest_objectives_#{@camp.id}"
    assert_includes response.body, "quest_progress_#{@camp.id}"
    refute_includes response.body, "Temp stream"
  end
end
