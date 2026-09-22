# frozen_string_literal: true

require "test_helper"

class BattleWinSaveFailureTest < ActionDispatch::IntegrationTest
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
    @battle = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project_leaf, horizon: "day",
      title: "A very long battle name that should still wrap on a narrow phone screen",
      scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    dismiss_onboarding_missions!(@user)
    @todo = @user.daily_todos.for_day.find_by!(strategy_goal_id: @battle.id)
  end

  test "Today turbo win save failure returns 422 and keeps row open" do
    invalid = DailyTodo.new
    invalid.errors.add(:base, "stub save failure")

    with_singleton_method_stub(Battles::CompleteTodo, :call, ->(*) { raise ActiveRecord::RecordInvalid.new(invalid) }) do
      post complete_daily_todo_path(@todo), as: :turbo_stream
    end

    assert_response :unprocessable_entity
    refute @todo.reload.completed?

    get dashboard_path
    assert_response :success
    assert_select "##{dom_id(@todo, :battlefield_row)}.lp-today-v2-row", count: 1
    assert_select "##{dom_id(@todo, :battlefield_row)} form.lp-today-v2-row__check-form button:not([disabled])", count: 1
    assert_select "##{dom_id(@todo, :battlefield_row)} [data-juicy-feedback-win-not-saved-value]",
                  text: I18n.t("dash.battlefield.win_not_saved")
  end

  test "Today turbo win ArgumentError from CompleteTodo returns 422" do
    with_singleton_method_stub(Battles::CompleteTodo, :call, ->(*) { raise ArgumentError, "checklist" }) do
      post complete_daily_todo_path(@todo), as: :turbo_stream
    end

    assert_response :unprocessable_entity
    refute @todo.reload.completed?
  end

  test "Mountain camp sheet win save failure returns 422 and keeps battle open" do
    invalid = StrategyGoal.new
    invalid.errors.add(:base, "stub save failure")

    with_singleton_method_stub(Battles::WinFromMountain, :call, ->(*) { raise ActiveRecord::RecordInvalid.new(invalid) }) do
      post battle_win_path(@battle), params: { source: "camp_sheet" }, as: :turbo_stream
    end

    assert_response :unprocessable_entity
    refute @battle.reload.completed?

    get life_journey_path(@journey, focus_id: @battle.parent_id)
    assert_response :success
    assert_select "#trail-battle-#{@battle.id}.is-open", count: 1
  end

  test "Mountain second win is idempotent success not 422" do
    post battle_win_path(@battle), params: { source: "camp_sheet" }, as: :turbo_stream
    assert_response :ok
    assert @battle.reload.completed?

    post battle_win_path(@battle), params: { source: "camp_sheet" }, as: :turbo_stream
    assert_response :ok
  end

  private

  def with_singleton_method_stub(object, method_name, impl)
    singleton = object.singleton_class
    original = singleton.instance_method(method_name)
    singleton.define_method(method_name, impl)
    yield
  ensure
    singleton.define_method(method_name, original)
  end
end
