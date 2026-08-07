# frozen_string_literal: true

require "test_helper"

class FixedViewportMountainTest < ActionDispatch::IntegrationTest
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

  test "mountain uses fixed-viewport planning shell" do
    project = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Resume", position: 0
    )
    project_leaf = practice_leaf_for!(project)
    project_leaf.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Update CV", scheduled_on: Date.current, position: 0
    )

    get life_journey_path(@journey, focus_id: project_leaf.id)
    assert_response :success
    assert_select ".lp-rpg.is-focus-phase"
    assert_select ".lp-rpg__chrome-top"
    assert_select ".lp-rpg__stage.is-planning"
    assert_select ".lp-rpg__planning"
    assert_select ".lp-rpg__stage-sections"
    assert_select ".lp-rpg__stage-trail"
    assert_select ".lp-climb-path"
    assert_select ".lp-rpg__stage-battle", count: 0
    assert_select ".lp-rpg__chrome-bottom", count: 0
    assert_select ".lp-rpg-stats", count: 0
    assert_select ".lp-rpg-sheet.is-quest-space", count: 0
    assert_select ".lp-rpg-breadcrumbs", count: 0
    assert_select ".lp-climb-path__node.is-selected .lp-climb-path__quests[open]"
    assert_select ".lp-climb-path__quest-title", text: /Steps|#{Regexp.escape(project_leaf.title)}/
    assert_select ".lp-rpg-camp-switch", count: 0
    assert_select ".lp-rpg-context", count: 0
  end

  test "climb path lists done current and capped locked camps" do
    5.times do |i|
      camp = @plan.children.create!(
        user: @user, life_area: @area, life_journey: @journey,
        horizon: "project", title: "Camp #{i}", position: i
      )
      camp.complete! if i < 2
    end

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @plan.id)
    assert_response :success
    assert_select ".lp-climb-path__node.is-done", count: 2
    assert_select ".lp-climb-path__node.is-current", count: 1
    assert_select ".lp-climb-path__node.is-locked", count: 2
    assert_match(/Project Sections/i, response.body)
  end

  test "climb path still renders with few camps" do
    2.times do |i|
      @plan.children.create!(
        user: @user, life_area: @area, life_journey: @journey,
        horizon: "project", title: "Camp #{i}", position: i
      )
    end

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @plan.id)
    assert_response :success
    assert_select ".lp-climb-path__node.is-current", count: 1
    assert_select ".lp-climb-path__node.is-current a.lp-climb-path__link", minimum: 1
  end

  test "planning center de-dupes progress and never exposes battle win" do
    project = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Daily battles", position: 0
    )
    project_leaf = practice_leaf_for!(project)
    project_leaf.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Design battle card",
      description: "Sketch the card layout",
      scheduled_on: Date.current, position: 0
    )
    @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Side path", position: 1
    )

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: project_leaf.id)
    assert_response :success

    assert_select ".lp-rpg-summit", minimum: 1
    assert_select ".lp-rpg-stat.is-mountain", count: 0
    assert_select ".lp-rpg-sheet__cue", count: 0
    assert_no_match(/battle_wins|battle_win/, response.body)
    assert_select "form[action*='battle_win']", count: 0

    assert_select ".lp-rpg-path.is-focus .lp-rpg-path__pct", minimum: 1
    assert_select ".lp-rpg-plan-rail__item:not(.is-focus):not(.is-add) .lp-rpg-path__pct", count: 0

    assert_select ".lp-climb-path__quests[open]", minimum: 1
    assert_select ".lp-climb-path__quest-title", text: /Steps/i
    assert_select ".lp-climb-path__quest-add-input"
    assert_select ".lp-rpg-camp-switch", count: 0
    assert_select ".lp-rpg-camp-folder__cta", count: 0
    assert_select ".lp-rpg-practice-add", text: /Prepare New Quest/i, count: 0
    assert_select ".lp-rpg-breadcrumbs", count: 0
    assert_select ".lp-climb-path__node.is-selected", text: /Daily battles/
    assert_select "#rpg-add-checkpoint"
  end
end
