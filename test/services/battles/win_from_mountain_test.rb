# frozen_string_literal: true

require "test_helper"

class Battles::WinFromMountainTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @area = life_areas(:one_self)
    @goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "Goal", position: 0)
    @plan = @user.strategy_goals.create!(
      life_area: @area, parent: @goal, horizon: "plan", title: "Plan", position: 0
    )
    @camp = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Camp", position: 0
    )
    @camp_leaf = practice_leaf_for!(@camp)
  end

  test "off-day weekly win does not advance schedule or award AP" do
    off_day = (Date.current.wday + 1) % 7
    battle = @user.strategy_goals.create!(
      life_area: @area,
      parent: @camp_leaf,
      horizon: "day",
      title: "Off-day weekly",
      scheduled_on: Date.current,
      repeat: "weekly",
      repeat_weekdays: [ off_day ],
      position: 0
    )
    scheduled_before = battle.scheduled_on

    assert_no_difference -> { @user.reload.life_points } do
      result = Battles::WinFromMountain.call(battle: battle, user: @user, session: {})
      assert_equal 0, result.awarded
    end

    battle.reload
    assert_equal scheduled_before, battle.scheduled_on
    assert_nil battle.completed_at
    refute @user.daily_todos.for_day.exists?(strategy_goal_id: battle.id)
  end

  test "due-day weekly win advances schedule without completing the battle" do
    battle = @user.strategy_goals.create!(
      life_area: @area,
      parent: @camp_leaf,
      horizon: "day",
      title: "Due today weekly",
      scheduled_on: Date.current,
      repeat: "weekly",
      repeat_weekdays: [ Date.current.wday ],
      position: 0
    )
    expected = battle.next_weekly_occurrence(after: Date.current)

    assert_difference -> { @user.reload.life_points }, GameRules::BATTLE_TODO_LP do
      result = Battles::WinFromMountain.call(battle: battle, user: @user, session: {})
      assert_equal GameRules::BATTLE_TODO_LP, result.awarded
    end

    battle.reload
    assert_equal expected, battle.scheduled_on
    assert_nil battle.completed_at
    todo = @user.daily_todos.for_day.find_by(strategy_goal_id: battle.id)
    assert todo&.completed_at.present?
  end
end
