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

  test "empty leaf shows Now and Camps snap rows with ghost add cards" do
    project = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Resume", position: 0
    )

    get life_journey_path(@journey, focus_id: project.id)
    assert_response :success
    assert_select ".lp-rpg-sheet__title", text: /Resume/
    assert_select ".lp-rpg-sheet-rail.is-now[data-controller~='strategy-plan-rail']"
    assert_select ".lp-rpg-sheet-rail.is-camps[data-controller~='strategy-plan-rail']"
    assert_select ".lp-rpg-sheet-rail.is-now .lp-rpg-add.is-ghost.is-step"
    assert_select ".lp-rpg-sheet-rail.is-camps .lp-rpg-add.is-ghost.is-checkpoint"
    assert_select ".lp-rpg-sheet-rail__label", text: /NOW/
    assert_select ".lp-rpg-sheet-rail__label", text: /SPLIT INTO CAMPS/
    assert_select ".lp-rpg-trail .lp-rpg-node", text: /Resume/
  end

  test "leaf with day children shows Now row only and keeps battle win" do
    project = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Resume", position: 0
    )
    battle = project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Update CV", scheduled_on: Date.current, position: 0
    )

    get life_journey_path(@journey, focus_id: project.id)
    assert_response :success
    assert_select ".lp-rpg-sheet-rail.is-now"
    assert_select ".lp-rpg-now-card__title", text: /Update CV/
    assert_select ".lp-rpg-now-card__xp", text: /xp/i
    assert_select "form[action=?]", battle_win_path(battle)
    assert_select ".lp-rpg-sheet-rail.is-camps", count: 0
  end

  test "branch checkpoint sheet lists camps in a horizontal snap row" do
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
    assert_select ".lp-rpg-sheet-rail.is-camps[data-controller~='strategy-plan-rail']"
    assert_select ".lp-rpg-camp-card__title", text: /Landing page/
    assert_select ".lp-rpg-camp-card__title", text: /Payments/
    assert_select ".lp-rpg-sheet-rail.is-camps .lp-rpg-add.is-ghost.is-checkpoint"
    assert_select ".lp-rpg-sheet-rail.is-now", count: 0
    assert_select ".lp-rpg-now-card", count: 0
    assert_select "a.lp-rpg-camp-card[href*='focus_id=#{child.id}']"

    # Trail stays plan-level only — nested child is not a trail node
    assert_select ".lp-rpg-trail .lp-rpg-node", text: /Launch prep/
    assert_select ".lp-rpg-trail .lp-rpg-node", text: /Landing page/, count: 0
  end

  test "focusing a nested child recurses into leaf Now sheet" do
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
    assert_select ".lp-rpg-now-card__title", text: /Draft hero/
    assert_select ".lp-rpg-sheet.is-branch", count: 0
    assert_select ".lp-rpg-sheet-rail.is-camps", count: 0
  end
end
