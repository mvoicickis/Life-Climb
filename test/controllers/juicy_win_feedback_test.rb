# frozen_string_literal: true

require "test_helper"

class JuicyWinFeedbackTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @user.update!(character: "fox", support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
    @journey = @user.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.find(&:plan?)
    @section = @plan.children.find(&:project?)
    @leaf = @section

    @leaf.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Write tests", scheduled_on: Date.current, position: 1
    )

    quest = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Volume",
      position: @plan.children.maximum(:position).to_i + 1
    )
    host = Strategy::EnsureFolderQuest.call(folder: quest)
    host.practice_tasks.create!(user: @user, title: "Do a lesson", position: 0)

    Strategy::CascadeToDaily.call(user: @user, life_area: @area)

    @user.habits.destroy_all
    @user.habits.create!(
      name: "Meditate", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth"
    )
    @user.habits.create!(
      name: "Pages", unit: "pages", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", goal: 10
    )
  end

  test "battle Win form wires juicy-feedback with suppress reload celebrate" do
    todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Write tests")
    get dashboard_path
    assert_response :success

    assert_select ".lp-dash-tcard[data-todo-id=?][data-lp]", todo.id
    assert_select ".lp-dash-tcard[data-todo-id=?] form[data-controller='juicy-feedback'][data-juicy-feedback-suppress-reload-celebrate-value='true']",
                  todo.id
    assert_select ".lp-dash-tcard[data-todo-id=?] form[action=?][data-controller='juicy-feedback']",
                  todo.id, complete_daily_todo_path(todo)
  end

  test "completed battle undo Win does not wire suppress juicy-feedback" do
    todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Write tests")
    post complete_daily_todo_path(todo)
    follow_redirect!

    assert_select ".lp-dash-done-fold .lp-dash-tcard[data-todo-id=?] form[action=?]", todo.id, complete_daily_todo_path(todo)
    assert_select ".lp-dash-tcard[data-todo-id=?] form[data-juicy-feedback-suppress-reload-celebrate-value='true']",
                  todo.id, count: 0
  end

  test "habit Win wires juicy-feedback without suppress or data-lp" do
    enable_habits!
    get dashboard_path
    assert_response :success

    assert_select ".lp-dash-anytime .lp-dash-tcard.is-habit[data-lp]", count: 0
    assert_select ".lp-dash-anytime form[data-controller='juicy-feedback']", minimum: 1
    assert_select ".lp-dash-anytime form[data-controller~='juicy-feedback']", minimum: 1
    assert_select ".lp-dash-anytime form[data-juicy-feedback-suppress-reload-celebrate-value='true']", count: 0
  end

  test "nested checkbox wires juicy-feedback without suppress" do
    get dashboard_path
    assert_response :success

    assert_select "dialog.lp-dash-quest-sheet .lp-dash-checklist__obj form[data-controller='juicy-feedback']",
                  minimum: 1
    assert_select ".lp-dash-quest-next form[data-controller='juicy-feedback']", minimum: 1
    assert_select "dialog.lp-dash-quest-sheet .lp-dash-checklist__obj form[data-juicy-feedback-suppress-reload-celebrate-value='true']",
                  count: 0
  end

  test "shield tip shows once and dismiss marks milestone" do
    refute @user.day_shield_tip_done?

    get dashboard_path
    assert_response :success
    assert_select "[data-day-shield-tip='true']", count: 1
    assert_match(/Your shield is ready — it can save one missed window today/, response.body)

    delete day_shield_tip_path
    assert_redirected_to dashboard_path
    assert @user.reload.day_shield_tip_done?

    get dashboard_path
    assert_response :success
    assert_select "[data-day-shield-tip='true']", count: 0
  end
end
