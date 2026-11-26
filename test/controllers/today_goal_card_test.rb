# frozen_string_literal: true

require "test_helper"

class TodayGoalCardTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    @journey = seed_climb!(@user, today_mission: "Ship auth")
    dismiss_onboarding_missions!(@user)
    @goal = @user.strategy_goals.for_kind("goal").roots.find_by!(life_journey_id: @journey.id)
    @camp = Strategy::PathProject.resolve(user: @user, journey: @journey)
    assert @camp.present?
  end

  test "header shows Your goal kicker, camp name, bar, and won count" do
    clear_camp_battles!
    first = add_camp_battle!("Fight one", position: 0, on: Date.current)
    add_camp_battle!("Fight two", position: 1, on: Date.current)
    first.update!(completed_at: Time.current)
    @user.daily_todos.for_day(Date.current).where(strategy_goal_id: first.id).update_all(completed_at: Time.current)

    get dashboard_path
    assert_response :success

    assert_select "#today-battlefield-header .lp-today-goal-kicker", text: "Your goal", count: 1
    assert_select "#today-battlefield-header .lp-today-goal-camp", text: @camp.title, count: 1
    assert_select "#today-battlefield-header .lp-today-camp-bar", count: 1
    bar = css_select("#today-battlefield-header .lp-today-camp-bar").first
    assert_equal "2", bar["aria-valuemax"]
    assert_equal "1", bar["aria-valuenow"]
    assert_select "#today-battlefield-header .lp-today-camp-bar__fill[data-today-goal-bar][style*='--lp-fill: 0.5']", count: 1
    assert_select "#today-battlefield-header .lp-today-camp-won", text: "1 won", count: 1
    assert_select "#today-battlefield-header .lp-today-v2-hp-bar", count: 0
    assert_select "#today-battlefield-count", count: 1
  end

  test "open camp with zero wins hides won count" do
    clear_camp_battles!
    add_camp_battle!("Open fight", position: 0)

    get dashboard_path
    assert_response :success

    assert_select "#today-battlefield-header .lp-today-goal-kicker", text: "Your goal", count: 1
    assert_select "#today-battlefield-header .lp-today-goal-camp", text: @camp.title, count: 1
    assert_select "#today-battlefield-header .lp-today-camp-bar", count: 1
    assert_select "#today-battlefield-header .lp-today-camp-won[hidden]", count: 1
  end

  test "goal card carries the collapse controller for scroll pad" do
    get dashboard_path
    assert_response :success

    assert_select "#today-battlefield-header .lp-today-group-card--goal[data-controller~='today-goal-card']",
                  count: 1
    assert_select ".lp-today-scroll__pad", count: 1
  end

  test "no camp means Your goal and title only" do
    @user.strategy_goals.where(horizon: "project", life_journey_id: @journey.id).find_each do |camp|
      camp.update_columns(completed_at: Time.current)
    end
    assert_nil Strategy::PathProject.resolve(user: @user, journey: @journey.reload)

    get dashboard_path
    assert_response :success

    assert_select "#today-battlefield-header .lp-today-goal-kicker", text: "Your goal", count: 1
    assert_select "#today-battlefield-header .lp-today-v2-header__name", count: 1
    assert_select "#today-battlefield-header .lp-today-goal-camp", count: 0
    assert_select "#today-battlefield-header .lp-today-camp-bar", count: 0
    assert_select "#today-battlefield-header .lp-today-camp-won", count: 0
  end

  test "long goal title stays on the card" do
    long_goal = "Build a calm software studio that helps families every week"
    @goal.update!(title: long_goal)

    get dashboard_path
    assert_response :success

    assert_select "#today-battlefield-header .lp-today-v2-header__name[title=?]", long_goal
  end

  test "goal card bar reflects today's battle share" do
    clear_camp_battles!
    todos = 3.times.map { |i| add_camp_battle!("Fight #{i}", position: i, on: Date.current) }
    todos.each do |battle|
      assert @user.daily_todos.for_day(Date.current).exists?(strategy_goal_id: battle.id)
    end

    get dashboard_path
    assert_response :success
    assert_select "#today-battlefield-header .lp-today-camp-bar__fill[style*='--lp-fill: 0.0']", count: 1

    todo = @user.daily_todos.for_day(Date.current).find_by!(strategy_goal_id: todos.first.id)
    post complete_daily_todo_path(todo), as: :turbo_stream
    assert_response :ok
    assert_match(/lp-today-camp-bar__fill[^>]*--lp-fill: 0\.33/, response.body)

    get dashboard_path
    assert_response :success
    assert_match(/--lp-fill: 0\.33/, css_select("#today-battlefield-header .lp-today-camp-bar__fill").first["style"])

    @user.daily_todos.for_day(Date.current).where(completed_at: nil).find_each do |row|
      post complete_daily_todo_path(row), as: :turbo_stream
      assert_response :ok
    end

    get dashboard_path
    assert_response :success
    assert_select "#today-battlefield-header .lp-today-camp-bar__fill[style*='--lp-fill: 1.0']", count: 1
  end

  test "goal card hides bar when no battles are scheduled today" do
    clear_camp_battles!
    battle = add_camp_battle!("Later", position: 0, on: Date.current + 1.day)
    battle.update!(completed_at: Time.current)

    get dashboard_path
    assert_response :success
    assert_select "#today-battlefield-header .lp-today-goal-camp", text: @camp.title, count: 1
    assert_select "#today-battlefield-header .lp-today-camp-bar", count: 0
    assert_select "#today-battlefield-header .lp-today-camp-won", text: "1 won", count: 1
  end

  test "win and undo streams update today's bar fill" do
    clear_camp_battles!
    first = add_camp_battle!("Fight one", position: 0, on: Date.current)
    add_camp_battle!("Fight two", position: 1, on: Date.current)
    todo = @user.daily_todos.for_day(Date.current).find_by!(strategy_goal_id: first.id)

    get dashboard_path
    assert_response :success
    assert_select "#today-battlefield-header .lp-today-camp-bar__fill[style*='--lp-fill: 0.0']", count: 1

    post complete_daily_todo_path(todo), as: :turbo_stream
    assert_response :ok
    assert_match %(target="today-battlefield-header"), response.body
    assert_match(/lp-today-camp-bar__fill[^>]*--lp-fill: 0\.5/, response.body)
    assert first.reload.completed_at.present?

    post complete_daily_todo_path(todo), as: :turbo_stream
    assert_response :ok
    assert_match %(target="today-battlefield-header"), response.body
    assert_match(/lp-today-camp-bar__fill[^>]*--lp-fill: 0\.0/, response.body)
    assert_nil first.reload.completed_at
  end

  private

  def clear_camp_battles!
    battle_ids = @camp.children.where(horizon: "day").pluck(:id)
    @user.daily_todos.where(strategy_goal_id: battle_ids).delete_all if battle_ids.any?
    @camp.children.where(horizon: "day").delete_all
  end

  def add_camp_battle!(title, position:, on: nil)
    battle = @camp.children.create!(
      user: @user,
      life_area: @journey.life_area,
      life_journey: @journey,
      horizon: "day",
      title: title,
      scheduled_on: on || Date.current + position.days,
      position: position
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @journey.life_area)
    battle
  end
end
