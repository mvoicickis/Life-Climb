# frozen_string_literal: true

require "test_helper"

class FixedViewportMountainTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
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
    assert_select ".lp-rpg.is-focus-phase.is-v4-phone"
    assert_select "#mountain-trail.lp-trail.is-v4"
    assert_select ".lp-trail-hud"
    assert_select ".lp-rpg__stage.is-planning.is-v4"
    assert_select ".lp-rpg__stage-trail.is-v4"
    assert_select "#trail-camp-#{project.id}", text: /Resume/
    assert_select ".lp-climb-path.is-list", minimum: 1
    assert_select "#climb-path-project-#{project.id} .lp-climb-path__title", text: "Resume"
    assert_select ".lp-rpg-scenic", count: 0
    assert_select ".lp-rpg__chrome-top", count: 0
    assert_select ".lp-rpg__stage-battle", count: 0
    assert_select ".lp-rpg__chrome-bottom", count: 0
    assert_select ".lp-rpg-stats", count: 0
    assert_select ".lp-rpg-sheet.is-quest-space", count: 0
    assert_select ".lp-rpg-breadcrumbs", count: 0
    assert_select ".lp-climb-path__quests", count: 0
    assert_select ".lp-rpg-camp-switch", count: 0
    assert_select ".lp-rpg-context", count: 0
    assert_select ".lp-dash-nav.is-v4"
    assert_select ".lp-dash-nav__fab"
  end

  test "climb path lists every camp without a lock window" do
    5.times do |i|
      camp = @plan.children.create!(
        user: @user, life_area: @area, life_journey: @journey,
        horizon: "project", title: "Camp #{i}", position: i
      )
      camp.complete! if i < 2
    end

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @plan.id)
    assert_response :success
    5.times do |i|
      camp = @plan.children.for_kind("project").find_by!(title: "Camp #{i}")
      if i < 2
        assert_select "#trail-camp-#{camp.id}", count: 0
      else
        assert_select "#trail-camp-#{camp.id}", text: /Camp #{i}/
      end
    end
    assert_select ".lp-climb-path__node.is-locked", count: 0
  end

  test "climb path still renders with few camps" do
    camps = 2.times.map do |i|
      @plan.children.create!(
        user: @user, life_area: @area, life_journey: @journey,
        horizon: "project", title: "Camp #{i}", position: i
      )
    end

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @plan.id)
    assert_response :success
    assert_select "#trail-camp-#{camps[0].id}", text: /Camp 0/
    assert_select "#trail-camp-#{camps[1].id}", text: /Camp 1/
    assert_select "a.lp-climb-path__link", count: 0
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

    assert_select ".lp-trail-hud"
    assert_select ".lp-trail-hud__stat", minimum: 1
    assert_select ".lp-rpg-stat.is-mountain", count: 0
    assert_select ".lp-rpg-sheet__cue", count: 0
    assert_select "#trail-sheet-body form[action*='battle_win']"

    assert_select "#trail-camp-#{project.id}", text: /Daily battles/
    assert_select ".lp-climb-path__quests", count: 0
    assert_select ".lp-rpg-camp-switch", count: 0
    assert_select ".lp-rpg-camp-folder__cta", count: 0
    assert_select ".lp-rpg-practice-add", text: /Prepare New Quest/i, count: 0
    assert_select ".lp-rpg-breadcrumbs", count: 0

    get objectives_strategy_goal_path(project)
    assert_response :success
    assert_select ".lp-climb-path__quest-title", text: /Daily battles/
    assert_select ".lp-climb-path__quest-add-input"
  end

  test "stylesheet keeps content-sized stage/planning/trail inside fixed 100dvh shell" do
    css = Rails.root.join("app/assets/tailwind/application.css").read
    shell = css[/\.lp-rpg\.is-focus-phase\s*\{[^}]+\}/m]
    stage = css[/\.lp-rpg\.is-focus-phase \.lp-rpg__stage\.is-planning\s*\{[^}]+\}/m]
    planning = css[/\.lp-rpg__planning\s*\{[^}]+\}/m]
    trail = css[/\.lp-rpg__stage-trail\s*\{[^}]+\}/m]
    focus_trail = css[/\.lp-rpg\.is-focus-phase \.lp-rpg__stage-sections\.lp-rpg__stage-trail\s*\{[^}]+\}/m]

    assert_match(/height:\s*100dvh/, shell)
    assert_match(/max-height:\s*100dvh/, shell)
    assert_match(/overflow:\s*hidden/, shell)
    assert_match(/display:\s*flex/, shell)
    assert_match(/flex-direction:\s*column/, shell)
    refute_match(/grid-template-rows:\s*auto\s+minmax\(0,\s*1fr\)/, shell)

    assert_match(/flex:\s*0\s+1\s+auto/, stage)
    assert_match(/margin-top:\s*auto/, stage)
    assert_match(/height:\s*max-content/, stage)

    assert_match(/^\s*height:\s*auto;/m, planning)
    assert_match(/max-height:\s*100%/, planning)
    assert_match(/grid-template-rows:\s*minmax\(0,\s*1fr\)\s+auto/, planning)
    refute_match(/^\s*height:\s*100%;/m, planning)

    assert_match(/align-self:\s*start/, trail)
    assert_match(/height:\s*max-content/, trail)
    assert_match(/max-height:\s*100%/, trail)
    assert_match(/overflow-y:\s*auto/, trail)
    assert_match(/height:\s*max-content/, focus_trail)
    assert_match(/max-height:\s*100%/, focus_trail)
  end
end
