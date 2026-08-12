# frozen_string_literal: true

require "test_helper"

class QuestColorTagTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, today_mission: "Write tests")
    @area = @user.primary_focused_journey.life_area
    @journey = @user.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.find(&:plan?)
    @section = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "MVP", position: @plan.children.maximum(:position).to_i + 1
    )
  end

  test "creating a leaf quest with color_key persists and shows on Mountain" do
    assert_difference -> { @user.strategy_goals.for_kind("project").count }, 1 do
      post strategy_goals_path, params: {
        life_area_id: @area.id,
        life_journey_id: @journey.id,
        horizon: "project",
        parent_id: @section.id,
        title: "Purple Volume",
        color_key: "purple"
      }
    end

    quest = @user.strategy_goals.for_kind("project").find_by!(title: "Purple Volume")
    assert_equal "purple", quest.color_key
    assert_redirected_to life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: quest.id)

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @section.id)
    assert_response :success
    assert_select ".lp-climb-path__quests[open]"
    assert_select ".lp-climb-path__quest.has-color.is-purple .lp-climb-path__quest-title", text: /Purple Volume/
    assert_select ".lp-color-swatches"
    assert_select "a.lp-qs-card", count: 0
  end

  test "blank color_key stays nil with default card styling" do
    post strategy_goals_path, params: {
      life_area_id: @area.id,
      life_journey_id: @journey.id,
      horizon: "project",
      parent_id: @section.id,
      title: "Plain Volume",
      color_key: ""
    }
    quest = @user.strategy_goals.for_kind("project").find_by!(title: "Plain Volume")
    assert_nil quest.color_key

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @section.id)
    assert_response :success
    assert_select ".lp-climb-path__quest-title", text: /Plain Volume/
    assert_select ".lp-climb-path__quest.has-color", text: /Plain Volume/, count: 0
    assert_select "a.lp-qs-card", count: 0
  end

  test "invalid color_key is rejected" do
    assert_no_difference -> { @user.strategy_goals.for_kind("project").count } do
      post strategy_goals_path, params: {
        life_area_id: @area.id,
        life_journey_id: @journey.id,
        horizon: "project",
        parent_id: @section.id,
        title: "Neon Volume",
        color_key: "neon"
      }
    end
    assert_response :redirect
  end

  test "Today quest cards show folder title and nested objectives" do
    quest = @section.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Teal Volume", position: 0, color_key: "teal"
    )
    host = Strategy::EnsureFolderQuest.call(folder: quest)
    host.practice_tasks.create!(user: @user, title: "Do a lesson", position: 0)
    host.practice_tasks.create!(user: @user, title: "Review notes", position: 1)
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)

    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-tcard.is-quest .lp-dash-tcard__title", text: "Teal Volume"
    assert_select ".lp-dash-tcard.is-quest .lp-dash-quest-next__step", text: /Do a lesson/
    assert_select ".lp-dash-tcard.is-quest dialog.lp-dash-quest-sheet .lp-dash-checklist__obj-name",
                  text: /Do a lesson/
    assert_select ".lp-dash-tcard.is-quest dialog.lp-dash-quest-sheet .lp-dash-checklist__obj-name",
                  text: /Review notes/
  end

  test "uncolored quest still renders as a quest card on Today" do
    quest = @section.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Plain Volume", position: 0
    )
    host = Strategy::EnsureFolderQuest.call(folder: quest)
    host.practice_tasks.create!(user: @user, title: "Do a lesson", position: 0)
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)

    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-tcard.is-quest .lp-dash-tcard__title", text: "Plain Volume"
    assert_select ".lp-dash-tcard.is-quest .lp-dash-quest-next__step", minimum: 1
    assert_select ".lp-dash-tcard.is-quest dialog.lp-dash-quest-sheet .lp-dash-checklist__obj", minimum: 1
  end

  test "quest detail edit dialog can update color_key" do
    quest = @section.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Edit me", position: 0
    )

    patch strategy_goal_path(quest), params: { title: "Edit me", color_key: "coral" }
    assert_equal "coral", quest.reload.color_key

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: quest.id)
    assert_response :success
    assert_select ".lp-climb-path__quest.has-color.is-coral .lp-climb-path__quest-title", text: /Edit me/
    assert_select "#quest-edit-#{quest.id} .lp-color-swatch.is-coral input[checked]"
  end
end
