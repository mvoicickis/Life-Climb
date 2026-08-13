# frozen_string_literal: true

require "test_helper"

class BattleWinsControllerTest < ActionDispatch::IntegrationTest
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
    @goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    @plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan", title: "Plan", position: 0
    )
    @project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "Project", position: 0
    )
    @project_leaf = practice_leaf_for!(@project)
    @battle = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @project_leaf, horizon: "day",
      title: "Win this fight", scheduled_on: Date.current, position: 0
    )
  end

  test "winning a battle from mountain returns to mountain with celebrate flash" do
    assert_difference -> { @user.reload.life_points }, GameRules::BATTLE_TODO_LP do
      post battle_win_path(@battle)
    end

    assert @battle.reload.completed?
    assert_response :redirect
    assert_match(%r{/life_journeys/#{@journey.id}}, @response.redirect_url)
    assert_includes @response.redirect_url, "focus_id=#{@project_leaf.id}"
    assert_equal GameRules::BATTLE_TODO_LP, flash[:ap_gained].to_i
    assert flash[:battle_celebrate]

    follow_redirect!
    assert_response :success
    assert_select ".lp-rpg"
  end

  test "BattleWins after Today undo awards nothing" do
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    todo = @user.daily_todos.for_day.find_by!(strategy_goal_id: @battle.id)

    Battles::CompleteTodo.call(todo: todo, user: @user, session: {})
    assert_equal GameRules::BATTLE_TODO_LP, LifePointLedger.where(source: todo).where("amount > 0").sum(:amount)

    Battles::UncompleteTodo.call(todo: todo, user: @user)
    assert_nil todo.reload.completed_at
    refute @battle.reload.completed?

    assert_no_difference -> { @user.reload.life_points } do
      post battle_win_path(@battle)
    end

    assert @battle.reload.completed?
    assert_equal 0, flash[:ap_gained].to_i
    assert_equal 0, LifePointLedger.where(source: @battle).where("amount > 0").count
    assert_equal 1, LifePointLedger.where(source: todo).where("amount > 0").count
  end

  test "BattleWins after mountain win does not double via Completing linked todo" do
    post battle_win_path(@battle)
    assert @battle.reload.completed?

    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    todo = @user.daily_todos.for_day.find_by(strategy_goal_id: @battle.id)
    skip "no linked daily todo" if todo.blank?

    Battles::UncompleteTodo.call(todo: todo, user: @user) if todo.completed?
    @battle.reopen! if @battle.reload.completed?
    todo.update!(completed_at: nil) if todo.reload.completed?

    assert_no_difference -> { @user.reload.life_points } do
      Battles::CompleteTodo.call(todo: todo.reload, user: @user, session: {})
    end
  end
end
