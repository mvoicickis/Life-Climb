# frozen_string_literal: true

require "test_helper"

class TodayBattlefieldWonRoadTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "Live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Code",
      closer_percent: 20
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Project", position: 0
    )
    project_leaf = practice_leaf_for!(project)
    battle = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project_leaf, horizon: "day",
      title: "Last Battle", scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    dismiss_onboarding_missions!(@user)
    @todo = @user.daily_todos.for_day.find_by!(strategy_goal_id: battle.id)
  end

  test "last battle win keeps won shell and inline ack without replacing battlefield body" do
    post complete_daily_todo_path(@todo), as: :turbo_stream

    assert_response :ok
    assert_no_match %(turbo-stream action="remove" target="#{dom_id(@todo, :battlefield_row)}"), response.body
    assert_match %(turbo-stream action="replace" target="#{dom_id(@todo, :battlefield_row)}"), response.body
    assert_no_match %(turbo-stream action="replace" target="today-battlefield-body"), response.body
    assert_match "today-battlefield-won-shell", response.body
    assert_no_match "today-eod-ack-host", response.body
    assert_match "battle-day-stream-bridge", response.body
    assert_match 'data-battle-day-stream-bridge-celebrate-value="true"', response.body
  end

  test "undo after all clear restores open row and clears celebrate bridge" do
    post complete_daily_todo_path(@todo), as: :turbo_stream
    assert_response :ok
    assert @todo.reload.completed?

    post complete_daily_todo_path(@todo), as: :turbo_stream

    assert_response :ok
    refute @todo.reload.completed?
    assert_no_match "battle-day-stream-bridge", response.body
    assert_match %(turbo-stream action="append" target="today-battlefield-rows"), response.body

    get dashboard_path
    assert_response :success
    assert_select "#today-battlefield-rows ##{dom_id(@todo, :battlefield_row)}", count: 1
  end
end
