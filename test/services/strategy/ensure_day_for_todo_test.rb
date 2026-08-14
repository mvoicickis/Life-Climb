# frozen_string_literal: true

require "test_helper"

class Strategy::EnsureDayForTodoTest < ActiveSupport::TestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @journey = seed_climb!(@user, today_mission: "Ship auth")
  end

  test "returns existing strategy_goal when already linked" do
    todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Ship auth")
    day = todo.strategy_goal
    assert day.present?

    assert_no_difference -> { @user.strategy_goals.where(horizon: "day").count } do
      assert_equal day, Strategy::EnsureDayForTodo.call(todo: todo)
    end
  end

  test "provisions a day goal and links orphan todo without duplicating DailyTodo" do
    orphan = @user.daily_todos.create!(
      title: "Orphan MVP battle",
      aspect_key: "career",
      scheduled_on: Date.current,
      position: 99,
      lp_reward: GameRules::BATTLE_TODO_LP
    )
    assert_nil orphan.strategy_goal_id

    assert_difference -> { @user.strategy_goals.where(horizon: "day").count }, 1 do
      assert_no_difference -> { @user.daily_todos.for_day(Date.current).count } do
        day = Strategy::EnsureDayForTodo.call(todo: orphan)
        assert_equal day.id, orphan.reload.strategy_goal_id
        assert_equal "Orphan MVP battle", day.title
      end
    end

    assert_equal 1, @user.daily_todos.where(title: "Orphan MVP battle", scheduled_on: Date.current).count

    # Idempotent retry
    assert_no_difference -> { @user.strategy_goals.where(horizon: "day").count } do
      assert_no_difference -> { @user.daily_todos.for_day(Date.current).count } do
        Strategy::EnsureDayForTodo.call(todo: orphan.reload)
      end
    end
    assert_equal 1, @user.daily_todos.where(title: "Orphan MVP battle", scheduled_on: Date.current).count
  end

  test "attaches orphan under last-touched incomplete path Project" do
    journey = @journey
    goal = @user.strategy_goals.for_kind("goal").roots.first
    plan = goal.children.for_kind("plan").ordered.first
    first = plan.children.for_kind("project").ordered.first
    second = plan.children.create!(
      user: @user, life_area: journey.life_area, life_journey: journey,
      horizon: "project", title: "Second camp", position: first.position.to_i + 5
    )
    leaf = second
    recent = leaf.children.create!(
      user: @user, life_area: journey.life_area, life_journey: journey,
      horizon: "day", title: "Recent under second", scheduled_on: Date.yesterday, position: 0
    )
    recent.update_columns(updated_at: Time.current + 1.minute)

    orphan = @user.daily_todos.create!(
      title: "Orphan on second",
      aspect_key: "career",
      scheduled_on: Date.current,
      position: 99,
      lp_reward: GameRules::BATTLE_TODO_LP
    )

    day = Strategy::EnsureDayForTodo.call(todo: orphan)
    path = day.parent
    path = path.parent while path && !path.path_level_camp?
    assert_equal second.id, path.id
  end

  test "empty spine attaches orphan to the holding camp" do
    @user = users(:two)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Empty mountain",
      ideal_scene: "Done",
      current_reality: "Start",
      today_mission: "Anything",
      closer_percent: 10,
      route_mission: true
    )
    orphan = @user.daily_todos.create!(
      title: "Loose orphan",
      aspect_key: "career",
      scheduled_on: Date.current,
      position: 0,
      lp_reward: GameRules::BATTLE_TODO_LP
    )

    day = Strategy::EnsureDayForTodo.call(todo: orphan)
    assert day.parent.holding?
    refute_equal "Loose orphan", day.parent.title
  end
end
