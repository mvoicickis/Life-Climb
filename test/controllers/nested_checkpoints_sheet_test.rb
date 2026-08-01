# frozen_string_literal: true

require "test_helper"

class NestedCheckpointsSheetTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
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
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Main trail", position: 0
    )
  end

  test "leaf checkpoint sheet matches pre-change dailies behavior and offers split when empty" do
    project = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Resume", position: 0
    )

    get life_journey_path(@journey, focus_id: project.id)
    assert_response :success
    assert_select ".lp-rpg-sheet__title", text: /Resume/
    assert_select ".lp-rpg-sheet .lp-rpg-add", text: /Step|battle/i
    assert_select ".lp-rpg-sheet__split-link", text: /Split into smaller checkpoints/
    assert_select ".lp-rpg-checkpoints", count: 0
    assert_select ".lp-rpg-trail .lp-rpg-node", text: /Resume/

    project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Update CV", scheduled_on: Date.current, position: 0
    )

    get life_journey_path(@journey, focus_id: project.id)
    assert_response :success
    assert_select ".lp-rpg-battle", text: /Update CV/
    assert_select ".lp-rpg-sheet__split-link", count: 0
  end

  test "branch checkpoint sheet lists child checkpoints instead of dailies" do
    parent = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Launch prep", position: 0
    )
    child = parent.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Landing page", position: 0
    )
    parent.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Payments", position: 1
    )

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: parent.id)
    assert_response :success
    assert_select ".lp-rpg-sheet.is-branch"
    assert_select ".lp-rpg-checkpoint__title", text: /Landing page/
    assert_select ".lp-rpg-checkpoint__title", text: /Payments/
    assert_select ".lp-rpg-add.is-checkpoint", text: /Checkpoint/
    assert_select ".lp-rpg-sheet .lp-rpg-battle", count: 0
    assert_select ".lp-rpg-checkpoint__hit[href*='focus_id=#{child.id}']"

    # Trail stays plan-level only — nested child is not a trail node
    assert_select ".lp-rpg-trail .lp-rpg-node", text: /Launch prep/
    assert_select ".lp-rpg-trail .lp-rpg-node", text: /Landing page/, count: 0
  end

  test "focusing a nested child recurses into leaf sheet" do
    parent = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Launch prep", position: 0
    )
    child = parent.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Landing page", position: 0
    )
    child.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Draft hero", scheduled_on: Date.current, position: 0
    )

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: child.id)
    assert_response :success
    assert_select ".lp-rpg-sheet__title", text: /Landing page/
    assert_select ".lp-rpg-battle", text: /Draft hero/
    assert_select ".lp-rpg-sheet.is-branch", count: 0
  end
end
