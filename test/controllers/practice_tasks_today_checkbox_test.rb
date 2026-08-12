# frozen_string_literal: true

require "test_helper"

class PracticeTasksTodayCheckboxTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(character: "fox")
    sign_in_as @user
    @journey = seed_climb!(@user, today_mission: "Polish Today")
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

  test "Today renders nested step as checklist checkbox not Win button" do
    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-quest-next__step", text: /make todays page more nice/
    assert_select "dialog.lp-dash-quest-sheet .lp-dash-checklist__obj",
                  text: /make todays page more nice/
    assert_select ".lp-dash-check", minimum: 1
    assert_select ".lp-dash-tcard__win.is-nested", count: 0
  end

  test "completing nested step marks checkbox done with strikethrough class" do
    patch practice_task_path(@task), params: { completed: "1" }
    assert_redirected_to dashboard_path

    get dashboard_path
    assert_response :success
    assert_select "dialog.lp-dash-quest-sheet .lp-dash-checklist__obj.is-done .lp-dash-checklist__obj-name",
                  text: /make todays page more nice/
    assert_select "dialog.lp-dash-quest-sheet .lp-dash-check.is-on", minimum: 1
  end
end
