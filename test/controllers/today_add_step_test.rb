# frozen_string_literal: true

require "test_helper"

class TodayAddStepTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @user.update!(character: "fox")
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
    dismiss_onboarding_missions!(@user)
    @todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Ship auth")
    travel_to Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 10, 30, 0)
  end

  teardown do
    travel_back
  end

  test "Today V2 has no inline set-time form on battle rows" do
    assert_not @todo.timed?

    get dashboard_path
    assert_response :success

    assert_battle_row!(title: @todo.title, todo: @todo)
    assert_select ".lp-dash-tcard input[name='daily_todo[start_time]']", count: 0
    assert_select ".lp-dash-tcard input[name='daily_todo[end_time]']", count: 0
  end

  test "Add step on linked plain battle creates practice_task and flat quest row on Today" do
    assert @todo.strategy_goal_id.present?
    assert_not @todo.quest?

    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-tcard__menuitem", count: 0

    assert_difference -> { PracticeTask.count }, 1 do
      post strategy_goal_practice_tasks_path(@todo.strategy_goal), params: {
        title: "Outline the auth flow",
        return_to: "today"
      }
    end
    assert_redirected_to dashboard_path

    follow_redirect!
    assert_response :success
    assert @todo.reload.quest?
    assert_battle_row!(title: @todo.title, camp: "Auth", todo: @todo)
    assert_select ".lp-dash-quest-next__step", count: 0
    assert_select ".lp-dash-quest-sheet", count: 0
  end

  test "complete and undo step uses practice_tasks update and removes row when shell done" do
    day = @todo.strategy_goal
    task = day.practice_tasks.create!(user: @user, title: "Write test", position: 0)

    get dashboard_path
    assert_response :success
    assert_battle_row!(title: @todo.title, todo: @todo)

    patch practice_task_path(task), params: { completed: "1" }
    assert_redirected_to dashboard_path
    assert task.reload.completed?
    assert @todo.reload.completed?

    patch practice_task_path(task), params: { completed: "0" }
    assert_redirected_to dashboard_path
    assert_not task.reload.completed?
    assert_not @todo.reload.completed?

    follow_redirect!
    assert_battle_row!(title: @todo.title, todo: @todo)
  end

  test "nil-goal Add step provisions day, creates step, and keeps a single DailyTodo" do
    orphan = @user.daily_todos.create!(
      title: "Throwaway orphan battle",
      aspect_key: "career",
      scheduled_on: Date.current,
      position: 88,
      lp_reward: GameRules::BATTLE_TODO_LP
    )
    assert_nil orphan.strategy_goal_id

    assert_difference -> { PracticeTask.count }, 1 do
      assert_no_difference -> { @user.daily_todos.where(title: "Throwaway orphan battle", scheduled_on: Date.current).count } do
        post create_step_daily_todo_path(orphan), params: { title: "First checklist step" }
      end
    end
    assert_redirected_to dashboard_path

    orphan.reload
    assert orphan.strategy_goal_id.present?
    assert orphan.quest?
    assert_equal 1, @user.daily_todos.where(title: "Throwaway orphan battle", scheduled_on: Date.current).count
    assert_equal 1, orphan.strategy_goal.practice_tasks.where(title: "First checklist step").count

    follow_redirect!
    assert_battle_row!(title: orphan.title, todo: orphan)
    assert_select ".lp-dash-quest-sheet", count: 0
  end

  test "commitment still counts timed completed battles with practice_tasks" do
    journey = @user.primary_focused_journey
    Today::Commitment.apply_preset!(journey, "easy")

    day = @todo.strategy_goal
    day.practice_tasks.create!(user: @user, title: "Step A", position: 0)
    @todo.update!(start_time: "09:00", end_time: "10:00", completed_at: Time.current)

    progress = Today::Commitment.progress(user: @user, journey: journey)
    assert_equal 1, progress.battle_done
    assert_equal 1, progress.battle_required

    @user.daily_todos.create!(
      title: "Loose card",
      aspect_key: "career",
      scheduled_on: Date.current,
      completed_at: Time.current,
      position: 77
    )
    progress2 = Today::Commitment.progress(user: @user, journey: journey.reload)
    assert_equal 1, progress2.battle_done
  end
end
