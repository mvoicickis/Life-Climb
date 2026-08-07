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

  test "empty Path-level camp shows New Quest under climb path instead of Add Practice" do
    project = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Resume", position: 0
    )

    get life_journey_path(@journey, focus_id: project.id)
    assert_response :success
    assert_select ".lp-climb-path__node.is-selected", text: /Resume/
    assert_select ".lp-rpg-section-head", count: 0
    assert_select ".lp-rpg__stage-battle", count: 0
    assert_select ".lp-rpg-sheet.is-quest-space", count: 0
    assert_select ".lp-rpg-practice-cats__hint", count: 0
    assert_select ".lp-climb-path__node.is-selected .lp-climb-path__new-quest-btn", text: /New Quest/
    assert_select ".lp-climb-path__node.is-selected .lp-climb-path__quest", count: 0
    assert_select ".lp-rpg-practice-focus.is-entered", count: 0
    assert_select ".lp-rpg-practice-add", text: /Prepare New Quest/i, count: 0
    assert_select ".lp-rpg-sheet-rail.is-camps", count: 0
  end

  test "nested leaf with day children opens climb-path quest without battle win" do
    project = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Resume", position: 0
    )
    project_leaf = practice_leaf_for!(project)
    battle = project_leaf.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Update CV", scheduled_on: Date.current, position: 0
    )
    battle.practice_tasks.create!(user: @user, title: "Rewrite summary", position: 0)

    get life_journey_path(@journey, focus_id: project_leaf.id)
    assert_response :success
    assert_select ".lp-climb-path__node.is-selected .lp-climb-path__quests[open]"
    assert_select ".lp-climb-path__quest-title", text: /Steps|#{Regexp.escape(project_leaf.title)}/
    assert_select ".lp-qs-obj__text[value='Rewrite summary']"
    assert_select ".lp-rpg-camp-folder__cta", count: 0
    assert_select "form[action=?]", battle_win_path(battle), count: 0
    assert_select ".lp-rpg-sheet-rail.is-camps", count: 0
    assert_select ".lp-rpg-practice-focus.is-entered", count: 0
  end

  test "branch checkpoint lists child camps as climb-path quest titles" do
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
    assert_select ".lp-rpg-sheet.is-quest-space", count: 0
    assert_select ".lp-rpg-sheet.is-branch", count: 0
    assert_select ".lp-rpg-sheet-rail.is-camps", count: 0
    assert_select ".lp-climb-path__node.is-selected", text: /Launch prep/
    assert_select ".lp-climb-path__node.is-selected .lp-climb-path__quests[open]"
    assert_select ".lp-rpg-section-head", count: 0
    assert_select ".lp-rpg-breadcrumbs", count: 0
    assert_select ".lp-climb-path__quest-title", text: /Landing page/
    assert_select ".lp-climb-path__quest-title", text: /Payments/
    assert_select ".lp-climb-path__new-quest-btn", text: /New Quest/
    assert_select ".lp-qs-card__name", count: 0
    assert_select ".lp-rpg-practice-focus.is-entered", count: 0
    assert_select "turbo-frame#quest_objectives_#{child.id}"

    # Sections carousel stays plan-level only — nested child is not a section card
    assert_select ".lp-climb-path__node", text: /Launch prep/
    assert_select ".lp-climb-path__node .lp-climb-path__title", text: /Landing page/, count: 0
    assert_select ".lp-climb-path__quest-title", text: /Landing page/
  end

  test "focusing a nested child shows climb-path quest under its section" do
    parent = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Launch prep", position: 0
    )
    child = parent.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Landing page", position: 0
    )
    day = child.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Draft hero", scheduled_on: Date.current, position: 0
    )
    day.practice_tasks.create!(user: @user, title: "Write headline", position: 0)

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: child.id)
    assert_response :success
    assert_select ".lp-climb-path__node.is-selected", text: /Launch prep/
    assert_select ".lp-rpg-section-head", count: 0
    assert_select ".lp-climb-path__quests[open] .lp-climb-path__quest-title", text: /Landing page/
    assert_select ".lp-qs-obj__text[value='Write headline']"
    assert_select ".lp-rpg-breadcrumbs", count: 0
    assert_select ".lp-rpg-practice-focus.is-entered", count: 0
    assert_select ".lp-rpg-sheet.is-branch", count: 0
    assert_select ".lp-rpg-sheet-rail.is-camps", count: 0
  end

  test "path focus shows sections in climb path and drills into the active section" do
    project = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Landing page", position: 0
    )
    project_leaf = practice_leaf_for!(project)
    project_leaf.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Write hero copy", scheduled_on: Date.current, position: 0
    )
    branch = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Launch prep", position: 1
    )
    branch.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Payments", position: 0
    )

    get life_journey_path(@journey, focus_id: @plan.id)
    assert_response :success
    assert_select ".lp-climb-path__node", text: /Landing page/
    assert_select ".lp-climb-path__node.is-locked", text: /Launch prep/
    assert_select ".lp-climb-path__node.is-current, .lp-climb-path__node.is-selected", text: /Landing page/
    assert_select ".lp-rpg-section-head", count: 0
    assert_select ".lp-climb-path__quest-title", text: /Steps/
    assert_select ".lp-rpg-sheet.is-quest-space", count: 0
    assert_select ".lp-rpg-practice-focus.is-entered", 0
  end
end
