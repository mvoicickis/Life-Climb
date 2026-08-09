# frozen_string_literal: true

require "test_helper"

class TodayChecklistShellTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, today_mission: "Write tests")
    @area = @user.primary_focused_journey.life_area
    @journey = @user.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.find(&:plan?)
    @section = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "MVP", position: @plan.children.maximum(:position).to_i + 1
    )
    @folder = @section.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Volume 0", position: 0
    )
    @host = Strategy::EnsureFolderQuest.call(folder: @folder)
  end

  test "creating a host day cascades to Today with folder display title" do
    todo = @user.daily_todos.for_day(Date.current).find_by(strategy_goal_id: @host.id)
    assert todo.present?
    assert_equal "Volume 0", todo.title
    assert_equal Strategy::EnsureFolderQuest::HOST_TITLE, @host.title
  end

  test "creating an objective keeps Today row titled with the folder name" do
    post strategy_goal_practice_tasks_path(@host), params: { title: "Do a lesson" }
    assert_redirected_to life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @folder.id)

    todo = @user.daily_todos.for_day(Date.current).find_by!(strategy_goal_id: @host.id)
    assert_equal "Volume 0", todo.title
    assert @host.practice_tasks.exists?(title: "Do a lesson")

    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-tcard.is-quest .lp-dash-tcard__title", text: "Volume 0"
    assert_select ".lp-dash-tcard.is-quest .lp-dash-checklist__obj-name", text: "Do a lesson"
    assert_select ".lp-dash-tcard.is-quest .lp-dash-tcard__win.is-locked", minimum: 1
    assert_select "form[action=?]", complete_daily_todo_path(todo), count: 0
  end

  test "checking one objective does not complete the day early" do
    first = @host.practice_tasks.create!(user: @user, title: "Do a lesson", position: 0)
    second = @host.practice_tasks.create!(user: @user, title: "Review notes", position: 1)
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    todo = @user.daily_todos.for_day(Date.current).find_by!(strategy_goal_id: @host.id)

    assert_no_difference -> { @user.reload.life_points } do
      patch practice_task_path(first), params: { completed: "1" }
    end
    assert_redirected_to dashboard_path
    assert first.reload.completed?
    assert_not second.reload.completed?
    assert_not todo.reload.completed?
    assert_not @host.reload.completed?
    assert_nil flash[:battle_celebrate]
  end

  test "completing the last objective finishes the day with AP and celebrate" do
    first = @host.practice_tasks.create!(user: @user, title: "Do a lesson", position: 0)
    second = @host.practice_tasks.create!(user: @user, title: "Review notes", position: 1)
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    todo = @user.daily_todos.for_day(Date.current).find_by!(strategy_goal_id: @host.id)
    first.complete!

    assert_difference -> { @user.reload.life_points }, GameRules::BATTLE_TODO_LP do
      patch practice_task_path(second), params: { completed: "1" }
    end
    assert_redirected_to dashboard_path
    assert second.reload.completed?
    assert todo.reload.completed?
    assert @host.reload.completed?
    assert_equal true, flash[:battle_celebrate]
    assert_equal GameRules::BATTLE_TODO_LP, flash[:ap_gained].to_i
  end

  test "undoing an objective after day finish reopens the day" do
    first = @host.practice_tasks.create!(user: @user, title: "Do a lesson", position: 0)
    second = @host.practice_tasks.create!(user: @user, title: "Review notes", position: 1)
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    todo = @user.daily_todos.for_day(Date.current).find_by!(strategy_goal_id: @host.id)

    patch practice_task_path(first), params: { completed: "1" }
    patch practice_task_path(second), params: { completed: "1" }
    assert todo.reload.completed?

    patch practice_task_path(second), params: { completed: "0" }
    assert_redirected_to dashboard_path
    assert_not second.reload.completed?
    assert first.reload.completed?
    assert_not todo.reload.completed?
    assert_not @host.reload.completed?
  end

  test "shell complete is blocked while objectives remain open" do
    @host.practice_tasks.create!(user: @user, title: "Do a lesson", position: 0)
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    todo = @user.daily_todos.for_day(Date.current).find_by!(strategy_goal_id: @host.id)

    post complete_daily_todo_path(todo)
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_match(/Finish the objectives first/i, response.body)
    assert_not todo.reload.completed?
  end

  test "objective taps do not open quantity dialog markup" do
    @section.update!(target_amount: 100, unit: "pages")
    assert @section.quantified?
    task = @host.practice_tasks.create!(user: @user, title: "Do a lesson", position: 0)
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)

    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-tcard.is-quest form[action=?]", practice_task_path(task)
    assert_select ".lp-dash-tcard.is-quest [data-controller='quantity-complete']", count: 0
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password12345" }
  end
end
