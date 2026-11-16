# frozen_string_literal: true

require "test_helper"

class TodayFocusedGoalBattlesTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    @first = seed_climb!(@user, area_key: "career", title: "Save for business", today_mission: "Call broker")
    dismiss_onboarding_missions!(@user)
    @second = seed_second_journey!(
      title: "Go public climb",
      area_key: "career",
      battle_title: "Pitch investors"
    )
    Strategy::CascadeToDaily.call(
      user: @user,
      life_area: @first.life_area,
      from: Date.current,
      to: Date.current
    )
  end

  test "Today lists only the focused journey battles" do
    assert_equal @first.id, @user.primary_focused_journey.id

    get dashboard_path
    assert_response :success

    assert_select "#today-battlefield-rows", text: /Call broker/
    assert_select "#today-battlefield-rows", text: /Pitch investors/, count: 0
    assert_equal 1, css_select("#today-battlefield-rows .lp-today-v2-row").size
  end

  test "switching focus changes the battle list and counts" do
    get dashboard_path
    assert_response :success
    assert_select "#today-battlefield-rows", text: /Call broker/
    assert_equal 1, css_select("#today-battlefield-rows .lp-today-v2-row").size
    assert_equal 1, Today::BattleOpenCount.for(user: @user, on: Date.current)

    Focus::SetJourneys.call(user: @user, journey_ids: [ @second.id ])
    get dashboard_path
    assert_response :success
    assert_select "#today-battlefield-rows", text: /Pitch investors/
    assert_select "#today-battlefield-rows", text: /Call broker/, count: 0
    assert_equal 1, css_select("#today-battlefield-rows .lp-today-v2-row").size
    assert_equal 1, Today::BattleOpenCount.for(user: @user, on: Date.current)

    Focus::SetJourneys.call(user: @user, journey_ids: [ @first.id ])
    get dashboard_path
    assert_response :success
    assert_select "#today-battlefield-rows", text: /Call broker/
    assert_select "#today-battlefield-rows", text: /Pitch investors/, count: 0
    assert_equal 1, Today::BattleOpenCount.for(user: @user, on: Date.current)
  end

  test "battlefield count matches the focused list after a win" do
    todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Call broker")

    post complete_daily_todo_path(todo), as: :turbo_stream
    assert_response :ok

    get dashboard_path
    assert_response :success
    assert_select "#today-battlefield-count:not([hidden])", text: /1/
    assert_match(/\b1\b.*\b1\b/, css_select("#today-battlefield-count").text.gsub(/\s+/, " "))
  end

  test "ad-hoc todo without strategy goal still shows" do
    @user.daily_todos.create!(
      title: "Buy stamps",
      aspect_key: "career",
      scheduled_on: Date.current,
      position: 99,
      lp_reward: 10
    )

    get dashboard_path
    assert_response :success

    assert_select "#today-battlefield-rows", text: /Call broker/
    assert_select "#today-battlefield-rows", text: /Buy stamps/
    assert_select "#today-battlefield-rows", text: /Pitch investors/, count: 0
  end

  test "another users todos never show" do
    other = users(:two)
    seed_climb!(other, area_key: "career", title: "Other climb", today_mission: "Other fight")
    other_todo = other.daily_todos.for_day(Date.current).ordered.first
    assert other_todo.present?

    get dashboard_path
    assert_response :success

    assert_select "##{ActionView::RecordIdentifier.dom_id(other_todo, :battlefield_row)}", count: 0
    assert_select "#today-battlefield-rows", text: /Other fight/, count: 0
  end

  test "empty focused goal keeps empty battlefield cta" do
    battle_ids = @user.strategy_goals.where(life_journey_id: @first.id, horizon: "day").pluck(:id)
    @user.daily_todos.where(strategy_goal_id: battle_ids).delete_all
    @user.strategy_goals.where(id: battle_ids).find_each { |b| b.update!(scheduled_on: Date.current + 30) }
    Strategy::CascadeToDaily.call(
      user: @user,
      life_area: @first.life_area,
      from: Date.current,
      to: Date.current
    )

    get dashboard_path
    assert_response :success

    assert_select "#today-battlefield-rows .lp-today-v2-row", count: 0
    assert_select ".lp-today-empty-cta__wrap", count: 1
    assert_select ".lp-today-empty-cta__pill", count: 1
  end

  private

  def seed_second_journey!(title:, area_key:, battle_title:)
    LifeAreas::Select.call(user: @user, keys: [ area_key ])
    area = @user.life_areas.v2_selected.find_by!(key: area_key)
    journey = Journeys::Create.call(
      user: @user,
      life_area: area,
      title: title,
      ideal_scene: "Ideal #{title}",
      current_reality: "Present #{title}",
      next_win: "Next #{title}",
      closer_percent: 20
    )
    goal = @user.strategy_goals.create!(
      user: @user,
      life_area: area,
      life_journey: journey,
      horizon: "goal",
      title: title,
      position: 0
    )
    plan = goal.children.create!(
      user: @user, life_area: area, life_journey: journey,
      horizon: "plan", title: "Plan #{title}", position: 0
    )
    project = plan.children.create!(
      user: @user, life_area: area, life_journey: journey,
      horizon: "project", title: "Camp #{title}", position: 0
    )
    project.children.create!(
      user: @user, life_area: area, life_journey: journey,
      horizon: "day", title: battle_title, scheduled_on: Date.current, position: 0
    )
    journey
  end
end
