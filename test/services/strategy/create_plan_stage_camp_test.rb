# frozen_string_literal: true

require "test_helper"

class Strategy::CreatePlanStageCampTest < ActiveSupport::TestCase
  include MountainTrailHelper

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
    @a = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project",
      title: "Done camp", position: 0, stage: 0
    )
    @b = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project",
      title: "Open stage 2", position: 1, stage: 1
    )
    @c = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project",
      title: "Open stage 3", position: 2, stage: 2
    )
    @a.complete!
    Strategy::SyncCompletion.call(project: @a)
  end

  test "new camp lands on chosen stage before later stages" do
    camp = Strategy::CreatePlanStageCamp.call(
      user: @user, plan: @plan, stage: 0, title: "Back on stage 1"
    )

    assert_equal 0, camp.stage
    assert_equal "Back on stage 1", camp.title
    assert_nil camp.completed_at
    assert_operator camp.position, :<, @b.reload.position
    assert_operator camp.position, :<, @c.reload.position

    projects = [ @a.reload, @b, @c, camp ]
    assert_equal 0, mountain_trail_open_stage(projects)
    trail = Strategy::Trail.for(plan: @plan.reload)
    assert_equal camp.id, trail.current_node.record.id
  end
end
