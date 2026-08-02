# frozen_string_literal: true

require "test_helper"

class ProjectSectionsMockupTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user, area_key: "career", title: "Ship LifePoints",
      ideal_scene: "App live", current_reality: "Building", next_win: "Launch",
      today_mission: "Write tests", closer_percent: 20, route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Main trail", position: 0
    )
    @active = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "MVP", position: 0
    )
    @locked = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Launch", position: 1
    )
  end

  test "carousel matches mockup skeleton with New Project" do
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @active.id)
    assert_response :success

    assert_select ".lp-rpg-sections__kicker", text: /Project Sections/i
    assert_select ".lp-rpg-section-card.is-current.is-selected", text: /MVP/
    assert_select ".lp-rpg-section-card.is-current .lp-rpg-section-card__top"
    assert_select ".lp-rpg-section-card.is-current .lp-rpg-section-card__menu-btn"
    assert_select ".lp-rpg-section-card.is-current .lp-rpg-section-card__icon"
    assert_select ".lp-rpg-section-card.is-current .lp-rpg-section-card__badge", text: "1"
    assert_select ".lp-rpg-section-card.is-current .lp-rpg-section-card__meter"
    assert_select ".lp-rpg-section-card.is-current .lp-rpg-section-card__status", text: /Active/i
    assert_select ".lp-rpg-section-card.is-current .lp-rpg-section-card__pct"
    assert_select ".lp-rpg-sections__new-btn", text: /New Project/
  end

  test "locked cards keep dimmed meter and percent without menu" do
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @active.id)
    assert_response :success

    assert_select ".lp-rpg-section-card.is-locked", text: /Launch/
    assert_select ".lp-rpg-section-card.is-locked .lp-rpg-section-card__meter-fill[style='width: 0%']"
    assert_select ".lp-rpg-section-card.is-locked .lp-rpg-section-card__pct", text: "0%"
    assert_select ".lp-rpg-section-card.is-locked .lp-rpg-section-card__status.is-locked", text: /Locked/i
    assert_select ".lp-rpg-section-card.is-locked .lp-rpg-section-card__menu-btn", count: 0
    assert_select ".lp-rpg-section-card.is-locked a.lp-rpg-section-card__link", count: 0
  end

  test "done cards have no menu" do
    @active.complete!
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @active.id)
    assert_response :success

    assert_select ".lp-rpg-section-card.is-done", text: /MVP/
    assert_select ".lp-rpg-section-card.is-done .lp-rpg-section-card__menu-btn", count: 0
    assert_select ".lp-rpg-section-card.is-current", text: /Launch/
    assert_select ".lp-rpg-section-card.is-current .lp-rpg-section-card__menu-btn", minimum: 1
  end

  test "empty plan shows New Project card" do
    empty = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Empty path", position: 1
    )
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: empty.id, focus_id: empty.id)
    assert_response :success
    assert_select ".lp-rpg-sections.is-empty .lp-rpg-sections__new-btn", text: /New Project/
    assert_select ".lp-rpg-section-card", count: 0
  end
end
