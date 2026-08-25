# frozen_string_literal: true

require "test_helper"

class PracticeTasksTodayCheckboxTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(character: "fox")
    sign_in_as @user
    @journey = seed_climb!(@user, today_mission: "Polish Today")
    dismiss_onboarding_missions!(@user)
    @journey.update!(
      commitment_key: "easy",
      commitment_name: "Easy",
      commitment_habit_count: 1,
      commitment_battle_count: 1
    )
    @user.habits.active.on_home.destroy_all
    @user.habits.create!(name: "Water", active: true, show_on_home: true, unit: "times")

    todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Polish Today")
    @day = todo.strategy_goal
    @task = @day.practice_tasks.create!(user: @user, title: "make todays page more nice", position: 0)
    Strategy::CascadeToDaily.call(user: @user, life_area: @journey.life_area)
  end

  test "Today V2 renders quest as flat row without nested checklist UI" do
    get dashboard_path
    assert_response :success
    assert_battle_row!(title: "Polish Today", camp: "Auth")
    assert_select ".lp-dash-quest-next__step", count: 0
    assert_select "dialog.lp-dash-quest-sheet", count: 0
    assert_select ".lp-dash-tcard__win.is-nested", count: 0
  end

  test "completing nested step finishes shell and removes battlefield row" do
    patch practice_task_path(@task), params: { completed: "1" }
    assert_redirected_to dashboard_path

    get dashboard_path
    assert_response :success
    assert_battle_row_absent!(title: "Polish Today")
    assert_select "dialog.lp-dash-quest-sheet", count: 0
  end
end
