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

  test "empty Path-level camp shows split-first instead of Add Practice" do
    project = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Resume", position: 0
    )

    get life_journey_path(@journey, focus_id: project.id)
    assert_response :success
    assert_select ".lp-rpg-sheet.is-categories"
    assert_select ".lp-rpg-section-head__title", text: /Resume/
    assert_select ".lp-rpg-practice-cats__hint", text: /smaller camps/i
    assert_select ".lp-rpg-camps .is-scope-add .lp-rpg-camps__new", text: /New Camp/i
    assert_select ".lp-rpg-practice-focus.is-entered", count: 0
    assert_select ".lp-rpg-camp-folder .lp-rpg-practice-add", text: /Prepare New Practice/i, count: 0
    assert_select ".lp-rpg-sheet-rail.is-camps", count: 0
    assert_select ".lp-rpg-section-card", text: /Resume/
  end

  test "nested leaf with day children shows Today's Practice without battle win" do
    project = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Resume", position: 0
    )
    project_leaf = practice_leaf_for!(project)
    battle = project_leaf.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Update CV", scheduled_on: Date.current, position: 0
    )

    get life_journey_path(@journey, focus_id: project_leaf.id)
    assert_response :success
    assert_select ".lp-rpg-camp-folder[open][data-category-id='#{project_leaf.id}']"
    assert_select ".lp-rpg-camp-switch__tab", text: /Today.?s Orders/i
    assert_select ".lp-rpg-camp-switch__tab", text: /All Practices/i
    assert_select ".lp-rpg-quest-row__title", text: /Update CV/
    assert_select ".lp-rpg-quest-row__xp", text: /XP/i
    assert_select ".lp-rpg-quest-row__check[checked]", minimum: 1
    assert_select ".lp-rpg-camp-folder__cta", text: /Begin Today.?s Battles/i
    assert_select "form[action=?]", battle_win_path(battle), count: 0
    assert_select ".lp-rpg-sheet-rail.is-camps", count: 0
    assert_select ".lp-rpg-camps:not([hidden])", 1
    assert_select ".lp-rpg-practice-focus.is-entered", count: 0
  end

  test "branch checkpoint sheet lists child camps as practice categories" do
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
    assert_select ".lp-rpg-sheet.is-categories"
    assert_select ".lp-rpg-sheet.is-branch", count: 0
    assert_select ".lp-rpg-sheet-rail.is-camps", count: 0
    assert_select ".lp-rpg-section-head__title", text: /Launch prep/
    assert_select ".lp-rpg-breadcrumbs__item", text: /Main trail/
    assert_select ".lp-rpg-section-head__title", text: /Launch prep/
    assert_select ".lp-rpg-camps .lp-rpg-practice-cat__title", text: /Landing page/
    assert_select ".lp-rpg-camps .lp-rpg-practice-cat__title", text: /Payments/
    assert_select ".lp-rpg-camps .lp-rpg-camp-row.is-leaf", minimum: 2
    assert_select ".lp-rpg-camps .is-scope-add .lp-rpg-camps__new", text: /New Camp/i
    assert_select ".lp-rpg-practice-focus.is-entered", count: 0
    assert_select ".lp-rpg-camp-folder[data-category-id='#{child.id}']"

    # Sections carousel stays plan-level only — nested child is not a section card
    assert_select ".lp-rpg-section-card", text: /Launch prep/
    assert_select ".lp-rpg-section-card", text: /Landing page/, count: 0
  end

  test "focusing a nested child opens that camp folder with branch crumb" do
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
    assert_select ".lp-rpg-section-head__title", text: /Launch prep/
    assert_select ".lp-rpg-camp-folder[open][data-category-id='#{child.id}'] .lp-rpg-practice-cat__title", text: /Landing page/
    assert_select ".lp-rpg-camp-folder[open] .lp-rpg-quest-row__title", text: /Draft hero/
    assert_select ".lp-rpg-breadcrumbs__item", text: /Launch prep/
    assert_select "a.lp-rpg-breadcrumbs__item[href*='focus_id=#{parent.id}']"
    assert_select ".lp-rpg-camps:not([hidden])", 1
    assert_select ".lp-rpg-practice-focus.is-entered", count: 0
    assert_select ".lp-rpg-sheet.is-branch", count: 0
    assert_select ".lp-rpg-sheet-rail.is-camps", count: 0
  end

  test "path focus shows sections in carousel and drills into the active section" do
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
    assert_select ".lp-rpg-section-card", text: /Landing page/
    assert_select ".lp-rpg-section-card.is-locked", text: /Launch prep/
    assert_select ".lp-rpg-section-head__title", text: /Landing page/
    assert_select ".lp-rpg-camps .lp-rpg-practice-cat__title", text: /Steps/
    assert_select ".lp-rpg-camp-folder[open]", 0
    assert_select ".lp-rpg-practice-focus.is-entered", 0
  end
end
