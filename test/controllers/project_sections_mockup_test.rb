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

  test "locked cards keep dimmed meter and show menu" do
    @locked.update!(title: "Today's Page")
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @active.id)
    assert_response :success

    assert_select ".lp-rpg-section-card.is-locked .lp-rpg-section-card__title", text: "Today's Page"
    assert_select ".lp-rpg-section-card.is-locked .lp-rpg-section-card__title[title=?]", "Today's Page"
    assert_select ".lp-rpg-section-card.is-locked .lp-rpg-section-card__menu-btn", minimum: 1
    assert_select ".lp-rpg-sections__item.is-locked.is-menu-enabled .lp-rpg-section-card__menu-btn"
    assert_select ".lp-rpg-section-card.is-locked .lp-rpg-section-card__meter-fill[style='width: 0%']"
    assert_select ".lp-rpg-section-card.is-locked .lp-rpg-section-card__pct", text: "0%"
    assert_select ".lp-rpg-section-card.is-locked .lp-rpg-section-card__status.is-locked", text: /Locked/i
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

  test "rename succeeds on a locked section" do
    patch strategy_goal_path(@locked), params: { title: "Today's Page" }
    assert_response :redirect
    assert_equal "Today's Page", @locked.reload.title
    assert_not @locked.completed?

    follow_redirect!
    assert_response :success
    assert_select ".lp-rpg-section-card.is-locked .lp-rpg-section-card__title", text: "Today's Page"
    assert_select ".lp-rpg-section-card.is-current", text: /MVP/
  end

  test "delete succeeds on a locked section" do
    assert_difference -> { @plan.children.where(horizon: "project").count }, -1 do
      delete strategy_goal_path(@locked)
    end
    assert_response :redirect
    assert_not StrategyGoal.exists?(@locked.id)

    follow_redirect!
    assert_response :success
    assert_select ".lp-rpg-section-card", text: /Launch/, count: 0
    assert_select ".lp-rpg-section-card.is-current", text: /MVP/
  end

  test "mid-list locked delete advances unlock queue without renumbering positions" do
    section_c = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Polish", position: 2
    )
    position_a = @active.position
    position_b = @locked.position
    position_c = section_c.position

    delete strategy_goal_path(@locked)
    assert_response :redirect
    assert_not StrategyGoal.exists?(@locked.id)

    assert_equal position_a, @active.reload.position
    assert_equal position_c, section_c.reload.position
    assert_not_equal position_b, section_c.position

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @active.id)
    assert_response :success
    assert_select ".lp-rpg-section-card.is-current", text: /MVP/
    assert_select ".lp-rpg-section-card.is-locked", text: /Polish/
    assert_select ".lp-rpg-section-card", text: /Launch/, count: 0

    @active.complete!
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @active.id)
    assert_response :success
    assert_select ".lp-rpg-section-card.is-done", text: /MVP/
    assert_select ".lp-rpg-section-card.is-current", text: /Polish/
    assert_equal position_c, section_c.reload.position
  end
end
