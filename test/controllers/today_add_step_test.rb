# frozen_string_literal: true

require "test_helper"

class TodayAddStepTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @user.update!(character: "fox")
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
    @todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Ship auth")
    travel_to Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 10, 30, 0)
  end

  teardown do
    travel_back
  end

  test "Set time Start defaults to current time and End stays blank" do
    assert_not @todo.timed?

    get dashboard_path
    assert_response :success

    expected = Time.current.strftime("%H:%M")
    assert_select ".lp-dash-tcard[data-todo-id=?] input[name='daily_todo[start_time]'][value=?]",
                  @todo.id.to_s, expected
    assert_select ".lp-dash-tcard[data-todo-id=?] input[name='daily_todo[end_time]'][required]",
                  @todo.id.to_s
    assert_select ".lp-dash-tcard[data-todo-id=?] input[name='daily_todo[end_time]'][value]",
                  @todo.id.to_s, count: 0
  end

  test "Add step on linked plain battle creates practice_task and quest card on Today" do
    assert @todo.strategy_goal_id.present?
    assert_not @todo.quest?

    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-tcard[data-todo-id=?] .lp-dash-tcard__add-step-btn", @todo.id.to_s

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
    assert_select ".lp-dash-tcard.is-quest[data-todo-id=?]", @todo.id.to_s
    assert_select ".lp-dash-tcard[data-todo-id=?] .lp-dash-checklist__obj-name",
                  @todo.id.to_s, text: /Outline the auth flow/
    assert_select ".lp-dash-tcard[data-todo-id=?] .lp-dash-tcard__win.is-locked", @todo.id.to_s
    assert_select ".lp-dash-tcard[data-todo-id=?] .lp-dash-tcard__add-step-btn", @todo.id.to_s
  end

  test "complete and undo step uses practice_tasks update and unlocks shell when done" do
    day = @todo.strategy_goal
    task = day.practice_tasks.create!(user: @user, title: "Write test", position: 0)

    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-tcard[data-todo-id=?] .lp-dash-tcard__win.is-locked", @todo.id.to_s

    patch practice_task_path(task), params: { completed: "1" }
    assert_redirected_to dashboard_path
    assert task.reload.completed?
    # Last objective finishes the shell battle automatically.
    assert @todo.reload.completed?

    patch practice_task_path(task), params: { completed: "0" }
    assert_redirected_to dashboard_path
    assert_not task.reload.completed?
    assert_not @todo.reload.completed?

    follow_redirect!
    assert_select ".lp-dash-tcard[data-todo-id=?] .lp-dash-tcard__win.is-locked", @todo.id.to_s
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
    assert_select ".lp-dash-tcard.is-quest[data-todo-id=?]", orphan.id.to_s
    assert_select ".lp-dash-tcard[data-todo-id=?] .lp-dash-checklist__obj-name",
                  orphan.id.to_s, text: /First checklist step/
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
