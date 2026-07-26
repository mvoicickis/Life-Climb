# frozen_string_literal: true

require "test_helper"

class StrategyHandoffTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App in production",
      current_reality: "Still building",
      next_win: "Launch Beta",
      today_mission: "Write one test",
      closer_percent: 20
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
  end

  test "empty strategy points at locking the goal" do
    handoff = Strategy::Handoff.for(user: @user, journey: @journey)
    assert_match(/Lock your season goal/i, handoff[:label])
  end

  test "project handoff names the plan" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Become debt-free", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Find a job", position: 0
    )
    handoff = Strategy::Handoff.for(user: @user, journey: @journey)
    assert_match(/Add a project under “Find a job”/i, handoff[:label])
    assert_includes handoff[:href], "focus_id=#{plan.id}"
  end
end
