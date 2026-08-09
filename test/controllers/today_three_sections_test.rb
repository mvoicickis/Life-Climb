# frozen_string_literal: true

require "test_helper"

class TodayThreeSectionsTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
    @area = @user.primary_focused_journey.life_area
    @journey = @user.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.find(&:plan?)
    @section = @plan.children.find(&:project?)
    @leaf = @section.children.find(&:project?)

    # Extra plain battle
    @leaf.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Write tests", scheduled_on: Date.current, position: 1
    )

    # Quest checklist (custom color)
    @quest = @section.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Purple Volume", position: 1, color_key: "coral"
    )
    host = Strategy::EnsureFolderQuest.call(folder: @quest)
    host.practice_tasks.create!(user: @user, title: "Do a lesson", position: 0)
    host.practice_tasks.create!(user: @user, title: "Review notes", position: 1)

    # Uncolored quest → still renders as a quest card
    @plain_quest = @section.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Plain Volume", position: 2
    )
    plain_host = Strategy::EnsureFolderQuest.call(folder: @plain_quest)
    plain_host.practice_tasks.create!(user: @user, title: "Open notes", position: 0)

    Strategy::CascadeToDaily.call(user: @user, life_area: @area)

    @user.habits.destroy_all
    @binary = @user.habits.create!(
      name: "Meditate", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth"
    )
    @pages = @user.habits.create!(
      name: "Pages read", unit: "pages", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", goal: 10
    )
    @hidden = @user.habits.create!(
      name: "Hidden steps", unit: "steps", points: 5, frequency: "daily",
      active: true, show_on_home: false, stat_type: "growth", goal: 1000
    )
  end

  test "Today renders timeline battles/quests and Anytime habits without section headers" do
    get dashboard_path
    assert_response :success

    assert_select ".lp-dash-timeline", count: 1
    assert_select ".lp-dash-anytime", count: 1
    assert_select ".lp-dash-section.is-battles", count: 0
    assert_select ".lp-dash-section.is-quests", count: 0
    assert_select ".lp-dash-section.is-habits", count: 0

    assert_select ".lp-dash-tcard__title", text: "Ship auth"
    assert_select ".lp-dash-tcard__title", text: "Write tests"
    assert_select ".lp-dash-tcard.is-quest .lp-dash-tcard__title", text: "Purple Volume"
    assert_select ".lp-dash-tcard.is-quest .lp-dash-tcard__title", text: "Plain Volume"
    assert_select ".lp-dash-anytime .lp-dash-tcard__title", text: "Meditate"
    assert_select ".lp-dash-anytime .lp-dash-tcard__title", text: "Pages read"
    assert_select ".lp-dash-anytime .lp-dash-tcard__title", text: "Hidden steps", count: 0
  end

  test "quest cards nest objectives with Win controls" do
    get dashboard_path
    assert_response :success

    assert_select ".lp-dash-tcard.is-quest .lp-dash-checklist__obj-name", text: "Do a lesson"
    assert_select ".lp-dash-tcard.is-quest .lp-dash-checklist__obj-name", text: "Review notes"
    assert_select ".lp-dash-tcard.is-quest .lp-dash-tcard__win.is-locked", minimum: 1
  end

  test "binary habit completes from Today and quantity habit logs from Today" do
    post completions_path(habit_id: @binary.id)
    assert_redirected_to dashboard_path
    assert @binary.reload.completed_today?

    post daily_logs_path(habit_id: @pages.id),
         params: { return_to: "today", daily_log: { amount: 7 } }
    assert_redirected_to dashboard_path
    assert_equal 7, @pages.reload.today_amount.to_i
  end

  test "plain battle still completes from timeline" do
    todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Write tests")
    assert_difference -> { @user.reload.life_points }, GameRules::BATTLE_TODO_LP do
      post complete_daily_todo_path(todo)
    end
    assert todo.reload.completed?
  end
end
