# frozen_string_literal: true

require "test_helper"

class Today::EndOfDayTest < ActiveSupport::TestCase
  test "ready when battles clear and habits gate disabled" do
    health = Today::BattlefieldHealth.call(open_count: 0, total_count: 2)
    habits = [ Struct.new(:survived_today?).new(false) ]

    assert Today::EndOfDay.ready?(health: health, habits: habits, habits_gate_enabled: false)
  end

  test "not ready when battles remain" do
    health = Today::BattlefieldHealth.call(open_count: 1, total_count: 2)

    refute Today::EndOfDay.ready?(health: health, habits: [], habits_gate_enabled: false)
  end

  test "not ready when habits gate on and basics incomplete" do
    health = Today::BattlefieldHealth.call(open_count: 0, total_count: 1)
    habits = [ Struct.new(:survived_today?).new(false) ]

    refute Today::EndOfDay.ready?(health: health, habits: habits, habits_gate_enabled: true)
  end

  test "ready when habits gate on and all basics survived" do
    health = Today::BattlefieldHealth.call(open_count: 0, total_count: 1)
    habits = [ Struct.new(:survived_today?).new(true) ]

    assert Today::EndOfDay.ready?(health: health, habits: habits, habits_gate_enabled: true)
  end

  test "open_camps returns active projects under first plan" do
    user = users(:one)
    journey = user.life_journeys.active.first || begin
      Onboarding::Run.call(
        user: user,
        area_key: "money",
        title: "Goal",
        ideal_scene: "A",
        current_reality: "B",
        next_win: "C",
        today_mission: "D",
        closer_percent: 10
      )
      user.reload.primary_focused_journey
    end
    area = journey.life_area
    goal = user.strategy_goals.create!(
      life_area: area, life_journey: journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = user.strategy_goals.create!(
      life_area: area, life_journey: journey, parent: goal, horizon: "plan", title: "Plan", position: 0
    )
    open = user.strategy_goals.create!(
      life_area: area, life_journey: journey, parent: plan, horizon: "project", title: "Open", position: 0
    )
    user.strategy_goals.create!(
      life_area: area, life_journey: journey, parent: plan, horizon: "project",
      title: "Done", position: 1, completed_at: Time.current
    )

    camps = Today::EndOfDay.open_camps(strategy_goal: goal)

    assert_equal [ open ], camps
  end
end
