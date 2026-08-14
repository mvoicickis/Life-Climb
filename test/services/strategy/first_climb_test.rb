# frozen_string_literal: true

require "test_helper"

class Strategy::FirstClimbTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    allow_extra_climbs!(@user)
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
    @first = @user.strategy_goals.for_kind("goal").roots.first
  end

  test "builds the spine under the given goal, not roots.first" do
    second = @user.strategy_goals.create!(
      life_area: @journey.life_area,
      life_journey: @journey,
      horizon: "goal",
      title: "Health Summit",
      position: 1
    )

    result = Strategy::FirstClimb.call(
      user: @user,
      journey: @journey,
      goal: second,
      plan_title: "Run Path",
      today_action: "Jog around the block"
    )

    assert result.created?
    assert_equal second.id, result.goal.id
    assert_equal "Run Path", second.children.for_kind("plan").first.title
    assert_equal 0, @first.children.for_kind("plan").count
  end

  test "goal_title creates a new destination and hangs the plan under it" do
    result = Strategy::FirstClimb.call(
      user: @user,
      journey: @journey,
      goal_title: "Family Peak",
      plan_title: "Weekend dinners",
      today_action: "Text the family group"
    )

    assert result.created?
    family = StrategyGoal.for_kind("goal").roots.find_by!(title: "Family Peak")
    assert_equal family.id, result.goal.id
    refute_equal @first.id, family.id
    assert_equal "Weekend dinners", family.children.for_kind("plan").first.title
    assert_equal 0, @first.children.for_kind("plan").count
  end

  test "a second destination climb does not rewrite dest 1 or retire the done route" do
    Strategy::FirstClimb.call(
      user: @user,
      journey: @journey,
      goal: @first,
      plan_title: "Ship Path",
      today_action: "Write the failing test"
    )
    replaced_before = @journey.missions.where(status: "replaced").pluck(:id).sort
    dest1_plan_ids = @first.reload.children.for_kind("plan").pluck(:id).sort

    Strategy::FirstClimb.call(
      user: @user,
      journey: @journey,
      goal_title: "Family Peak",
      plan_title: "Weekend dinners",
      today_action: "Text the family group"
    )

    assert_equal dest1_plan_ids, @first.reload.children.for_kind("plan").pluck(:id).sort
    assert_equal "Ship Path", @first.children.for_kind("plan").first.title
    assert_equal replaced_before, @journey.missions.where(status: "replaced").pluck(:id).sort
    assert_equal "done", @journey.reload.setup_flags.stringify_keys[Onboarding::Run::ROUTE_FLAG]
  end

  test "refuses to climb when neither goal nor goal_title is given" do
    error = assert_raises(ArgumentError) do
      Strategy::FirstClimb.call(
        user: @user,
        journey: @journey,
        plan_title: "Anything",
        today_action: "Do it today"
      )
    end
    assert_match(/goal/i, error.message)
  end
end
