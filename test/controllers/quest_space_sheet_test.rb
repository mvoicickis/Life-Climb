# frozen_string_literal: true

require "test_helper"

class QuestSpaceSheetTest < ActionDispatch::IntegrationTest
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
    @section = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Resume", position: 0
    )
  end

  test "standalone quest board is gone; quests open from the project menu" do
    host = Strategy::EnsureFolderQuest.call(folder: @section)
    host.practice_tasks.create!(user: @user, title: "Learn 15 words", position: 0, completed_at: Time.current)
    host.practice_tasks.create!(user: @user, title: "Flashcards", position: 1)

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @section.id)
    assert_response :success
    assert_select ".lp-rpg__stage-battle", count: 0
    assert_select ".lp-rpg-sheet.is-quest-space", count: 0
    assert_select ".lp-qs-board__title", count: 0
    assert_select ".lp-climb-path__quests", count: 0
    assert_select "#climb-path-project-#{@section.id} [data-action='click->plan-card-menu#objectives']"
    assert_select ".lp-climb-path__new-quest-btn", count: 0
    assert_select ".lp-rpg-practice-add", text: /Prepare New Quest/i, count: 0

    get objectives_strategy_goal_path(@section)
    assert_response :success
    assert_select ".lp-climb-path__quest-title", text: /Resume/
    assert_select "#quest_progress_#{@section.id}", text: /1 \/ 2/
  end

  test "objectives sheet shows inline objectives and add" do
    host = Strategy::EnsureFolderQuest.call(folder: @section)
    host.practice_tasks.create!(user: @user, title: "Learn 15 words", position: 0)

    get objectives_strategy_goal_path(@section)
    assert_response :success
    assert_select ".lp-climb-path__quest-title", text: /Resume/
    assert_select ".lp-qs-obj__text[value='Learn 15 words']"
    assert_select ".lp-climb-path__quest-add-input"
    assert_select ".lp-climb-path__quest-add-btn", text: /\AAdd\z/
    assert_select ".lp-qs-obj__check[data-action]", count: 0
    assert_select "button.lp-qs-obj__check", count: 0
    assert_select "span.lp-qs-obj__check", minimum: 1
    assert_select "#quest_progress_#{@section.id}", text: /objectives done/
    assert_select "turbo-frame#quest_objectives_#{@section.id}"
  end

  test "empty path-level camp does not show New Quest on the card" do
    empty = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Empty section", position: 1
    )
    @section.complete!
    get life_journey_path(@journey, focus_id: empty.id)
    assert_response :success
    assert_select ".lp-rpg__stage-battle", count: 0
    assert_select ".lp-qs-board__title", count: 0
    assert_select ".lp-climb-path__new-quest-btn", count: 0
    assert_select ".lp-climb-path__quests", count: 0
    assert_select "#climb-path-project-#{empty.id} [data-action='click->plan-card-menu#objectives']"
  end

  test "later camp without days is still a peer card with no inline quest" do
    @section.complete!
    locked = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Fogged", position: 1
    )
    current = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Active", position: 0
    )
    @section.update!(position: 0)
    current.update!(position: 1)
    locked.update!(position: 2)

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: current.id)
    assert_response :success
    assert_select "#climb-path-project-#{locked.id} .lp-climb-path__title", text: /Fogged/
    assert_select ".lp-climb-path__node.is-locked", count: 0
    assert_select ".lp-climb-path__quests", count: 0
    assert_select ".lp-climb-path__new-quest-btn", count: 0
    assert_select "#climb-path-project-#{locked.id} [data-action='click->plan-card-menu#objectives']"
  end
end
