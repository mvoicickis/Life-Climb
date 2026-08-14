# frozen_string_literal: true

require "test_helper"

class PathFocusCarouselTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    allow_extra_climbs!(@user)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Debt free",
      ideal_scene: "Free",
      current_reality: "Building",
      next_win: "Job",
      today_mission: "Apply",
      closer_percent: 20,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan_a = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Find a job", position: 0
    )
    @plan_b = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Learn German", position: 1
    )
    @other = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey,
      horizon: "goal", title: "Health", position: 1
    )
    @other.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Run", position: 0
    )
  end

  test "paths row shows scroll label, focused path, and one focus panel with three actions" do
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan_a.id)
    assert_response :success

    assert_select ".lp-rpg-paths[data-controller='strategy-plan-rail']"
    assert_select ".lp-rpg-paths__label", count: 0
    assert_select ".lp-rpg-path.is-focus", text: /Find a job/i
    assert_select ".lp-rpg-path-focus", count: 1
    assert_select ".lp-rpg-path-focus__title", text: /Find a job/i
    assert_select ".lp-rpg-path-focus__action[data-action='strategy-plan-rail#placeCheckpoint']"
    assert_select ".lp-rpg-path-focus__action[data-action='strategy-plan-rail#editPath']"
    assert_select ".lp-rpg-path-focus__action[data-action='strategy-plan-rail#viewProgress']"
    assert_select "#rpg-add-checkpoint"
    assert_select ".lp-rpg-paths__cue", count: 0
    assert_select ".lp-rpg-empty-goal", count: 0
    assert_select ".lp-rpg-context", count: 0
  end

  test "zero xp and streak chips stay hidden for a fresh climber" do
    @user.update!(total_points: 0, climb_streak_days: 0, climb_streak_on: nil)
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan_a.id)
    assert_response :success

    assert_select ".lp-rpg-hud__chips .lp-rpg-chip.is-xp:not(.is-quiet)", count: 0
    assert_select ".lp-rpg-hud__chips .lp-rpg-chip.is-streak", count: 0
    assert_select ".lp-rpg-destination-menu__btn"
    # "New Destination" create is removed (one destination per journey).
    assert_select ".lp-rpg-destination-menu__item[data-action*='destination-switcher#openCreate']", count: 0
    assert_select ".lp-rpg-destination__new", count: 0
    assert_select ".lp-rpg-summit__pct", count: 0
  end

  test "switching path updates the single focus panel title" do
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan_b.id)
    assert_response :success

    assert_select ".lp-rpg-path.is-focus", text: /Learn German/i
    assert_select ".lp-rpg-path-focus", count: 1
    assert_select ".lp-rpg-path-focus__title", text: /Learn German/i
    assert_select ".lp-rpg-path-focus__title", text: /Find a job/i, count: 0
  end

  test "no destination dots or swipe UI even with multiple destinations in data" do
    get life_journey_path(@journey, goal_id: @goal.id)
    assert_response :success

    # Switching UI is gone: one static destination is shown regardless of data.
    assert_select ".lp-rpg-destination-carousel.is-single"
    assert_select ".lp-rpg-destination-dots", count: 0
    assert_select ".lp-rpg-destination-carousel__arrow", count: 0
    assert_select ".lp-rpg-destination-carousel__peek", count: 0
    assert_select ".lp-rpg-destination-swipe-hint", count: 0
  end
end
