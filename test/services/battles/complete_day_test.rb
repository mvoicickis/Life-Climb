# frozen_string_literal: true

require "test_helper"

class BattlesCompleteDayTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user,
      area_key: "money",
      title: "Financial freedom",
      ideal_scene: "Calm savings",
      current_reality: "Building budget",
      next_win: "Launch Beta",
      today_mission: "Review my budget",
      closer_percent: 20
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
  end

  test "complete day marks linked strategy battles and raises mountain percent" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Become debt-free", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Kill debt", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Cut spend", position: 0
    )
    battle_a = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project, horizon: "day",
      title: "Cancel subscription", scheduled_on: Date.current, position: 0
    )
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project, horizon: "day",
      title: "Call bank", scheduled_on: Date.current, position: 1
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)

    assert_equal 0, goal.progress_percent

    result = Battles::CompleteDay.call(user: @user)
    assert result.ok
    assert_operator result.awarded, :>, 0
    assert_equal 0, result.progress_before
    assert_equal 100, result.progress_after
    assert_match(/Mountain now 100%/i, result.message)

    assert battle_a.reload.completed?
    assert_equal 100, goal.reload.progress_percent
    assert @user.daily_todos.for_day.incomplete.none?
  end
end
