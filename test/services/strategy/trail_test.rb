# frozen_string_literal: true

require "test_helper"

class StrategyTrailTest < ActiveSupport::TestCase
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
    @goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Debt free", position: 0
    )
    @plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan", title: "Legal", position: 0
    )
  end

  test "empty plan has no nodes" do
    trail = Strategy::Trail.for(plan: @plan)
    assert_equal 0, trail.progress
    assert_empty trail.nodes
  end

  test "sequential unlock marks first incomplete project as current" do
    first = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "Register", position: 0
    )
    second = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "Tax", position: 1
    )

    trail = Strategy::Trail.for(plan: @plan.reload)
    assert_equal :current, trail.nodes[0].state
    assert_equal :locked, trail.nodes[1].state
    assert_equal first.id, trail.current_node.id

    first.complete!
    trail = Strategy::Trail.for(plan: @plan.reload)
    assert_equal :done, trail.nodes[0].state
    assert_equal :current, trail.nodes[1].state
    assert_equal second.id, trail.current_node.id
  end

  test "progress mirrors plan percent" do
    a = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "A", position: 0
    )
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "B", position: 1
    )
    a.complete!
    Strategy::SyncCompletion.call(project: a)

    trail = Strategy::Trail.for(plan: @plan.reload)
    assert_equal @plan.progress_percent.to_i, trail.progress
    assert_operator trail.progress, :>, 0
  end

  test "visible nodes stay focused around current" do
    5.times do |i|
      @user.strategy_goals.create!(
        life_area: @area, life_journey: @journey, parent: @plan, horizon: "project",
        title: "Step #{i}", position: i
      )
    end
    @plan.children.for_kind("project").ordered.limit(2).each(&:complete!)

    trail = Strategy::Trail.for(plan: @plan.reload)
    assert_operator trail.visible_nodes.size, :<=, 3
    assert_equal 3, trail.visible_nodes.size
    assert_includes trail.visible_nodes.map(&:state), :current
    assert_equal 5, trail.nodes.size
  end

  test "habit-linked improvement project skips sequential lock" do
    habit = habits(:one)
    first = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project",
      title: "Planned camp", position: 0
    )
    improve = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project",
      title: "Improve Income", position: 1
    )
    HabitProjectLink.create!(habit: habit, strategy_goal: improve)
    later = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project",
      title: "Later camp", position: 2
    )

    trail = Strategy::Trail.for(plan: @plan.reload)
    by_id = trail.nodes.index_by(&:id)

    assert_equal :current, by_id[first.id].state
    assert_equal :current, by_id[improve.id].state
    assert_equal :locked, by_id[later.id].state

    first.complete!
    trail = Strategy::Trail.for(plan: @plan.reload)
    by_id = trail.nodes.index_by(&:id)

    assert_equal :done, by_id[first.id].state
    assert_equal :current, by_id[improve.id].state
    assert_equal :current, by_id[later.id].state
  end
end
