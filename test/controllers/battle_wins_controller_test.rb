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

  test "winning a daily battle from mountain keeps it for tomorrow" do
    @battle.update!(repeat: "daily")
    Strategy::CascadeToDaily.call(user: @user, life_area: @area, from: Date.current, to: Date.current + 1.day)

    assert_difference -> { @user.reload.life_points }, GameRules::BATTLE_TODO_LP do
      post battle_win_path(@battle)
    end

    @battle.reload
    assert @battle.repeat_daily?
    assert_nil @battle.completed_at
    assert_equal Date.current + 1.day, @battle.scheduled_on
  end

  test "winning a battle as turbo stream replaces the row instead of redirecting" do
    assert_difference -> { @user.reload.life_points }, GameRules::BATTLE_TODO_LP do
      post battle_win_path(@battle), as: :turbo_stream
    end

    assert_response :ok
    assert_includes @response.media_type, "turbo-stream"
    assert_match "trail-battle-#{@battle.id}", response.body
    assert_match "is-done", response.body
    assert_match "trail-toast-host", response.body
    assert_match(/Won/, response.body)
    assert_no_match "turbo-stream action=\"replace\" target=\"trail-battles-", response.body
    assert @battle.reload.completed?

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select "[data-strategy-rpg-celebrate-value=?]", "false"
  end

  test "camp sheet turbo win with source is quiet without toast" do
    assert_difference -> { @user.reload.life_points }, GameRules::BATTLE_TODO_LP do
      post battle_win_path(@battle), params: { source: "camp_sheet" }, as: :turbo_stream
    end

    assert_response :ok
    assert_match %(action="remove" target="trail-battle-#{@battle.id}"), response.body
    assert_match "trail-battles-done-slot-#{@project.id}", response.body
    assert_match "trail-battle-#{@battle.id}", response.body
    assert_match "is-done", response.body
    assert_no_match %(action="replace" target="trail-battle-#{@battle.id}"), response.body
    assert_no_match "trail-toast-host", response.body
    assert_no_match(/Won/, response.body)
    assert @battle.reload.completed?
  end

  test "camp sheet win moves battle into done section without duplicating open list" do
    second = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @project_leaf, horizon: "day",
      title: "Second fight", scheduled_on: Date.current, position: 1
    )
    won = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @project_leaf, horizon: "day",
      title: "Already won", scheduled_on: Date.current, position: 2
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    todo = @user.daily_todos.for_day.find_by!(strategy_goal_id: won.id)
    Battles::CompleteTodo.call(todo: todo, user: @user, session: {})
    won.reload

    post battle_win_path(@battle), params: { source: "camp_sheet" }, as: :turbo_stream

    assert_response :ok
    assert_match %(action="remove" target="trail-battle-#{@battle.id}"), response.body
    assert_match "trail-battles-done-list-#{@project.id}", response.body
    assert_match "Win this fight", response.body
    assert_match "Already won", response.body
    assert_no_match %(action="replace" target="trail-battle-#{@battle.id}"), response.body
  end

  test "winning a daily battle as turbo stream shows done row and drops base camp" do
    @battle.update!(repeat: "daily")
    Strategy::CascadeToDaily.call(user: @user, life_area: @area, from: Date.current, to: Date.current + 1.day)

    assert_difference -> { @user.reload.life_points }, GameRules::BATTLE_TODO_LP do
      post battle_win_path(@battle), as: :turbo_stream
    end

    assert_response :ok
    assert_match "trail-battle-#{@battle.id}", response.body
    assert_match "action=\"remove\" target=\"trail-base-battle-#{@battle.id}\"", response.body
    assert_match "is-done", response.body
    @battle.reload
    assert @battle.repeat_daily?
    assert_nil @battle.completed_at
    assert_equal Date.current + 1.day, @battle.scheduled_on
  end
end
