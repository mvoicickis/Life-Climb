# frozen_string_literal: true

require "test_helper"

class Strategy::WeeklyPlanner::RepairHashTitlesTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Write tests",
      closer_percent: 20,
      route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
  end

  test "dry run reports matches without changing rows" do
    dumped = { "title" => "Get a job" }.to_s
    goal = create_day_goal!(title: "temp", scheduled_on: Date.current)
    goal.update_columns(title: dumped)
    todo = @user.daily_todos.create!(
      title: dumped,
      scheduled_on: Date.current,
      position: 99,
      aspect_key: @area.key,
      lp_reward: GameRules::BATTLE_TODO_LP
    )

    result = Strategy::WeeklyPlanner::RepairHashTitles.call(dry_run: true, logger: Logger.new(nil))
    assert result.dry_run
    assert_operator result.goals_matched, :>=, 1
    assert_operator result.todos_matched, :>=, 1
    assert_equal 0, result.goals_updated
    assert_equal 0, result.todos_updated
    assert_equal dumped, goal.reload.title
    assert_equal dumped, todo.reload.title
  end

  test "apply repairs matching rows and is idempotent" do
    dumped = { "title" => "Ship it" }.to_s
    goal = create_day_goal!(title: "temp", scheduled_on: Date.current + 1)
    goal.update_columns(title: dumped)
    todo = @user.daily_todos.create!(
      title: dumped,
      scheduled_on: Date.current,
      position: 100,
      aspect_key: @area.key,
      lp_reward: GameRules::BATTLE_TODO_LP
    )
    clean = @user.daily_todos.create!(
      title: "Already fine",
      scheduled_on: Date.current,
      position: 101,
      aspect_key: @area.key,
      lp_reward: GameRules::BATTLE_TODO_LP
    )

    result = Strategy::WeeklyPlanner::RepairHashTitles.call(dry_run: false, logger: Logger.new(nil))
    assert_not result.dry_run
    assert_equal "Ship it", goal.reload.title
    assert_equal "Ship it", todo.reload.title
    assert_equal "Already fine", clean.reload.title
    assert_operator result.goals_updated, :>=, 1
    assert_operator result.todos_updated, :>=, 1

    again = Strategy::WeeklyPlanner::RepairHashTitles.call(dry_run: false, logger: Logger.new(nil))
    assert_equal 0, again.goals_matched
    assert_equal 0, again.todos_matched
  end

  private

  def create_day_goal!(title:, scheduled_on:)
    goal = @user.strategy_goals.for_kind("goal").roots.first
    plan = goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Repair plan #{scheduled_on}", position: 90
    )
    project = plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Repair project #{scheduled_on}", position: 0
    )
    leaf = project
    @user.strategy_goals.create!(
      life_area: @area,
      life_journey: @journey,
      parent: leaf,
      horizon: "day",
      title: title,
      scheduled_on: scheduled_on,
      position: 0
    )
  end
end
