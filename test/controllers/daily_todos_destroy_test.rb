# frozen_string_literal: true

require "test_helper"

class DailyTodosDestroyTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(character: "fox")
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Find a job",
      ideal_scene: "Hired",
      current_reality: "Searching",
      today_mission: "Plan the path",
      closer_percent: 10,
      route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    @journey.update!(
      commitment_key: "medium",
      commitment_name: "Medium",
      commitment_habit_count: 3,
      commitment_battle_count: 3
    )
    travel_to Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 10, 0, 0)
  end

  teardown { travel_back }

  test "owner can destroy incomplete battle" do
    todo = Battles::QuickAddToday.call(user: @user, title: "Draft pitch").todo
    todo.update!(start_time: Time.current, end_time: 1.hour.from_now)

    assert_difference -> { @user.daily_todos.for_day(Date.current).count }, -1 do
      delete daily_todo_path(todo)
    end
    assert_redirected_to dashboard_path
    assert_not DailyTodo.exists?(todo.id)
  end

  test "destroying a won timed battle reduces commitment battle_done" do
    todo = Battles::QuickAddToday.call(user: @user, title: "Won fight").todo
    todo.update!(start_time: Time.current, end_time: 1.hour.from_now, completed_at: Time.current)

    progress = Today::Commitment.progress(user: @user, journey: @journey)
    assert_equal 1, progress.battle_done

    delete daily_todo_path(todo)
    assert_redirected_to dashboard_path

    progress = Today::Commitment.progress(user: @user.reload, journey: @journey.reload)
    assert_equal 0, progress.battle_done
  end

  test "another user cannot destroy this battle" do
    todo = Battles::QuickAddToday.call(user: @user, title: "Keep me").todo
    other = users(:two)
    sign_in_as other

    assert_no_difference -> { DailyTodo.count } do
      delete daily_todo_path(todo)
    end
  end
end
