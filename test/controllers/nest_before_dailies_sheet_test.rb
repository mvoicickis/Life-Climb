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

  test "empty Path-level camp does not show New Quest nested-folder form" do
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp.id)
    assert_response :success
    assert_select ".lp-climb-path__node.is-selected", text: /Learn German/
    assert_select ".lp-rpg-section-head", count: 0
    assert_select ".lp-rpg-breadcrumbs", count: 0
    assert_select ".lp-rpg__stage-battle", count: 0
    assert_select ".lp-qs-board__title", count: 0
    assert_select ".lp-rpg-practice-cats__hint", count: 0
    assert_select ".lp-climb-path__new-quest-btn", count: 0
    assert_select ".lp-climb-path__node.is-selected .lp-climb-path__quest", count: 0
    assert_select ".lp-rpg-practice-focus.is-entered", count: 0
    assert_select ".lp-rpg-practice-add", text: /Prepare New Quest/i, count: 0
  end

  test "Path-level camp with days shows climb-path quest" do
    day = @user.strategy_goals.create!(
      user: @user, life_area: @area, life_journey: @journey, parent: @camp,
      horizon: "day", title: "Do lessons", scheduled_on: Date.current, position: 0
    )
    day.practice_tasks.create!(user: @user, title: "Unit 1", position: 0)

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp.id)
    assert_response :success
    assert_select ".lp-climb-path__quest-title", text: /Learn German/
    assert_select ".lp-qs-obj__text[value='Unit 1']"
    assert_select ".lp-rpg-practice-add", text: /Prepare New Quest/i, count: 0
  end

  test "creating a nested project under Path-level camp is rejected" do
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: @camp.id, horizon: "project", title: "Vocabulary"
    }
    assert_response :redirect
    assert_equal 0, @camp.children.where(horizon: "project").count
  end

  test "creating a day under Path-level camp succeeds" do
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: @camp.id, horizon: "day", scheduled_on: Date.current.to_s,
      title: "Do lessons"
    }
    assert_response :redirect
    assert @user.strategy_goals.exists?(horizon: "day", title: "Do lessons", parent_id: @camp.id)
  end
end
