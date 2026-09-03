# frozen_string_literal: true

require "test_helper"

class DailyTodosCompleteStreamTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Write tests",
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
      title: "Stream Battle", scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    dismiss_onboarding_missions!(@user)
    @todo = @user.daily_todos.for_day.find_by!(strategy_goal_id: battle.id)
  end

  test "completing a battle as turbo stream removes row without redirecting" do
    post complete_daily_todo_path(@todo), as: :turbo_stream

    assert_response :ok
    assert_includes @response.media_type, "turbo-stream"
    assert_match %(action="remove" target="#{dom_id(@todo, :battlefield_row)}"), response.body
    assert_match "today-battlefield-count", response.body
    assert_match "battle-day-stream-bridge", response.body
    assert @todo.reload.completed?
  end

  test "turbo stream response includes celebrate bridge payload in stream body" do
    post complete_daily_todo_path(@todo), as: :turbo_stream

    assert_response :ok
    assert_match "data-battle-day-stream-bridge-celebrate-value=\"true\"", response.body
    assert_match "data-battle-day-stream-bridge-ap-gained-value=\"#{GameRules::BATTLE_TODO_LP}\"", response.body
    assert_match "data-battle-day-stream-bridge-win-number-value=\"#{@user.daily_todos.where.not(completed_at: nil).count}\"", response.body
    assert_match "data-battle-day-stream-bridge-push-offer-eligible-value=\"true\"", response.body
    assert_match %(turbo-stream action="append" target="today-dash-root"), response.body
    assert_no_match "data-battle-day-celebrate-value", response.body
  end

  test "push offer bridge is false after permission denied" do
    @user.update!(push_offer_permission_denied_at: Time.current)

    post complete_daily_todo_path(@todo), as: :turbo_stream

    assert_response :ok
    assert_match "data-battle-day-stream-bridge-push-offer-eligible-value=\"false\"", response.body
  end

  test "turbo stream personal best milestone renders climb reward dialog in host" do
    @user.update!(best_day_ap: 5)

    post complete_daily_todo_path(@todo), as: :turbo_stream

    assert_response :ok
    assert_match 'turbo-stream action="update" target="climb-reward-host"', response.body
    assert_match 'id="climb-reward"', response.body
    assert_match "data-climb-reward-auto-value=\"true\"", response.body
    assert_match "data-battle-day-stream-bridge-boss-value=\"true\"", response.body
    assert_match "lp-climb-reward is-boss", response.body
  end

  test "win form requests turbo stream" do
    get dashboard_path
    assert_response :success

    assert_select "form.lp-today-v2-row__check-form[action=?][data-turbo-stream='true']",
                  complete_daily_todo_path(@todo)
  end

  test "turbo stream eod recap matches cleared battlefield health" do
    post complete_daily_todo_path(@todo), as: :turbo_stream

    assert_response :ok
    assert_match "You won 1 of 1 battle", response.body
    assert_no_match "You won 0 of 1 battles", response.body
  end
end
