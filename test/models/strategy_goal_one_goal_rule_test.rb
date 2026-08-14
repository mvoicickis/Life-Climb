# frozen_string_literal: true

require "test_helper"

# The one-destination / one-plan rule and its Premium gating seam.
class StrategyGoalOneGoalRuleTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App live",
      current_reality: "Building",
      today_mission: "Write tests",
      closer_percent: 10,
      route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
  end

  test "a second destination in the same journey is invalid" do
    second = @user.strategy_goals.build(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Second summit", position: 1
    )

    assert_not second.valid?
    assert_includes second.errors[:base], I18n.t("strategy.rpg.one_destination_only")
  end

  test "a second non-holding plan under a goal is invalid" do
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan", title: "First plan", position: 0
    )

    second = @user.strategy_goals.build(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan", title: "Second plan", position: 1
    )

    assert_not second.valid?
    assert_includes second.errors[:base], I18n.t("strategy.rpg.one_plan_only")
  end

  test "the holding plan is exempt and can coexist with a real plan" do
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan", title: "Real plan", position: 0
    )

    Strategy::HoldingProject.ensure!(user: @user, journey: @journey)

    assert @goal.children.for_kind("plan").where(holding: true).exists?,
           "holding plan should be allowed alongside a real plan"
    assert_equal 1, @goal.children.for_kind("plan").not_holding.count
  end

  test "a destination in a different journey is allowed" do
    other_journey = @user.life_journeys.create!(
      life_area: @area, title: "Other climb", ideal_scene: "There", current_reality: "Here", status: "active"
    )

    other_goal = @user.strategy_goals.build(
      life_area: @area, life_journey: other_journey, horizon: "goal", title: "Other summit", position: 0
    )

    assert other_goal.valid?, other_goal.errors.full_messages.to_sentence
  end

  test "entitled users may create extra destinations and plans" do
    allow_extra_climbs!(@user)

    second_goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Second summit", position: 1
    )
    assert second_goal.persisted?

    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan", title: "Plan A", position: 0
    )
    plan_b = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan", title: "Plan B", position: 1
    )
    assert plan_b.persisted?
  end

  test "creating the first destination and first plan is allowed by default" do
    # @goal is the first destination (from onboarding). Its first plan is fine.
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan", title: "Only plan", position: 0
    )
    assert plan.persisted?
  end
end
