# frozen_string_literal: true

require "test_helper"

class Strategy::ReopenPlanCampTest < ActiveSupport::TestCase
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
      title: "Stage 1 camp", position: 0, stage: 0
    )
    @b = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project",
      title: "Stage 2 camp", position: 1, stage: 1
    )
    @c = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project",
      title: "Stage 3 camp", position: 2, stage: 2
    )

    @won1 = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @a, horizon: "day",
      title: "Won one", scheduled_on: Date.current, position: 0
    )
    @won2 = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @a, horizon: "day",
      title: "Won two", scheduled_on: Date.current, position: 1
    )
    @won1.complete!
    @won2.complete!
    @a.complete!
    Strategy::SyncCompletion.call(project: @a)

    assert @a.reload.completed?
    assert_equal 1, mountain_trail_open_stage([ @a, @b, @c ].map(&:reload))
  end

  test "open again keeps won battles and strength, adds one open battle, aligns trail" do
    strength_before = @user.action_points
    won_ids = [ @won1.id, @won2.id ]

    Strategy::ReopenPlanCamp.call(user: @user, camp: @a)

    @a.reload
    @won1.reload
    @won2.reload

    assert @won1.completed?
    assert @won2.completed?
    assert_equal strength_before, @user.reload.action_points

    open_days = @a.children.select { |d| d.day? && !d.holding? && !d.completed? }
    assert_equal 1, open_days.size
    assert_nil @a.completed_at
    assert_operator Strategy::Progress.percent(@a), :<, 100

    projects = [ @a, @b.reload, @c.reload ]
    assert_equal 0, mountain_trail_open_stage(projects)
    trail = Strategy::Trail.for(plan: @plan.reload)
    assert_equal @a.id, trail.current_node.record.id
    assert_equal won_ids.sort, [ @won1.id, @won2.id ].sort
  end

  test "rejects quantified camps" do
    @a.update_columns(completed_at: nil, manually_completed_at: nil)
    @a.update!(target_amount: 100, unit: "pages", current_amount: 100, quantity_kind: "up")
    @a.complete!

    assert_raises(Strategy::ReopenPlanCamp::Invalid) do
      Strategy::ReopenPlanCamp.call(user: @user, camp: @a.reload)
    end
  end
end
