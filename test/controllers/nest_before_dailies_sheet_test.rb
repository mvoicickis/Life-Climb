# frozen_string_literal: true

require "test_helper"

class NestBeforeDailiesSheetTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Find a job",
      ideal_scene: "Hired",
      current_reality: "Searching",
      next_win: "Interview",
      today_mission: "Apply",
      closer_percent: 20,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Find a job", position: 0
    )
    @camp = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Learn German", position: 0
    )
  end

  test "empty Path-level camp shows split-first UI without Add Practice" do
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp.id)
    assert_response :success
    assert_select ".lp-rpg-sheet.is-categories"
    assert_select ".lp-rpg-section-card", text: /Learn German/
    assert_select ".lp-rpg-section-head", count: 0
    assert_select ".lp-rpg-breadcrumbs", count: 0
    assert_select ".lp-rpg-practice-cats__hint", text: /Break this into smaller camps/i
    assert_select ".lp-qs-new__btn", text: /New Quest/
    assert_select ".lp-rpg-practice-focus.is-entered", count: 0
    assert_select ".lp-rpg-practice-add", text: /Prepare New Quest/i, count: 0
  end

  test "nested leaf camp opens Quest Space detail with sticky add" do
    nested = @camp.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Vocabulary", position: 0
    )

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: nested.id)
    assert_response :success
    assert_select ".lp-qs-detail.is-open .lp-qs-detail__title", text: /Vocabulary/
    assert_select ".lp-qs-detail__add-input"
    assert_select ".lp-qs-detail__empty", text: /No objectives yet/i
    assert_select ".lp-rpg-practice-add", text: /Prepare New Quest/i, count: 0
    assert_select ".lp-rpg-camp-switch", count: 0
    assert_select ".lp-rpg-breadcrumbs", count: 0
  end

  test "Path focus shows Learn German in Project Sections carousel" do
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @plan.id)
    assert_response :success
    assert_select ".lp-rpg-section-card", text: /Learn German/
    assert_select ".lp-rpg-section-card", text: /Learn German/
    assert_select ".lp-rpg-section-head", count: 0
    assert_select ".lp-rpg-practice-cats__hint", text: /smaller camps/i
    assert_select ".lp-rpg-practice-focus.is-entered", count: 0
  end

  test "legacy Path-level camp with days opens Quest Space detail without Prepare New Quest" do
    day = @user.strategy_goals.new(
      user: @user, life_area: @area, life_journey: @journey, parent: @camp,
      horizon: "day", title: "Do lessons", scheduled_on: Date.current, position: 0
    )
    day.save!(validate: false)
    day.practice_tasks.create!(user: @user, title: "Unit 1", position: 0)

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp.id)
    assert_response :success
    assert_select ".lp-qs-detail.is-open .lp-qs-detail__title", text: /Learn German/
    assert_select ".lp-qs-obj__text[value='Unit 1']"
    assert_select ".lp-rpg-practice-add", text: /Prepare New Quest/i, count: 0
  end

  test "creating a day under Path-level camp redirects with nest message" do
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: @camp.id, horizon: "day", scheduled_on: Date.current.to_s,
      title: "Do lessons"
    }
    assert_response :redirect
    assert_match(/smaller camp|daily practices/i, flash[:alert].to_s)
    assert_equal 0, @user.strategy_goals.where(horizon: "day", title: "Do lessons").count
  end
end
