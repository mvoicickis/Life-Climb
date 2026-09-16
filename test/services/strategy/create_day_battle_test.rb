# frozen_string_literal: true

require "test_helper"

class Strategy::CreateDayBattleTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    allow_extra_climbs!(@user)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship",
      ideal_scene: "Live",
      current_reality: "Build",
      next_win: "Launch",
      today_mission: "Test",
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
    @camp = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project",
      title: "Camp", position: 0, stage: 0
    )
  end

  test "creates open day for today and cascades to daily todos" do
    battle = Strategy::CreateDayBattle.call(user: @user, project: @camp, title: "Small step")

    assert battle.day?
    assert_nil battle.completed_at
    assert_equal Date.current, battle.scheduled_on
    assert @user.daily_todos.for_day.find_by(strategy_goal_id: battle.id)
  end
end
