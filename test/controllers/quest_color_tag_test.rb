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
  end

  test "creating a path camp with color_key persists and shows on Mountain" do
    assert_difference -> { @user.strategy_goals.for_kind("project").count }, 1 do
      post strategy_goals_path, params: {
        life_area_id: @area.id,
        life_journey_id: @journey.id,
        horizon: "project",
        parent_id: @plan.id,
        title: "Purple Volume",
        color_key: "purple"
      }
    end

    quest = @user.strategy_goals.for_kind("project").find_by!(title: "Purple Volume")
    assert_equal "purple", quest.color_key
    assert_redirected_to life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: quest.id)

    quest.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Checklist", scheduled_on: Date.current, position: 0
    )
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: quest.id)
    assert_response :success
    assert_select "#climb-path-project-#{quest.id} .lp-climb-path__project.has-color.is-purple"
    assert_select "#climb-path-project-#{quest.id} .lp-climb-path__title", text: /Purple Volume/
    assert_select "#section-edit-#{quest.id} .lp-color-swatches"
    assert_select "a.lp-qs-card", count: 0
  end

  test "blank color_key stays nil with default card styling" do
    post strategy_goals_path, params: {
      life_area_id: @area.id,
      life_journey_id: @journey.id,
      horizon: "project",
      parent_id: @plan.id,
      title: "Plain Volume",
      color_key: ""
    }
    quest = @user.strategy_goals.for_kind("project").find_by!(title: "Plain Volume")
    assert_nil quest.color_key

    quest.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Checklist", scheduled_on: Date.current, position: 0
    )
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: quest.id)
    assert_response :success
    assert_select "#climb-path-project-#{quest.id} .lp-climb-path__title", text: /Plain Volume/
    assert_select "#climb-path-project-#{quest.id} .lp-climb-path__project.has-color", count: 0
    assert_select "a.lp-qs-card", count: 0
  end

  test "invalid color_key is rejected" do
    assert_no_difference -> { @user.strategy_goals.for_kind("project").count } do
      post strategy_goals_path, params: {
        life_area_id: @area.id,
        life_journey_id: @journey.id,
        horizon: "project",
        parent_id: @plan.id,
        title: "Neon Volume",
        color_key: "neon"
      }
    end
    assert_response :redirect
  end

  test "Today quest cards show path camp title and nested objectives" do
    quest = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Teal Volume",
      position: @plan.children.maximum(:position).to_i + 1, color_key: "teal"
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
    quest = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Plain Volume",
      position: @plan.children.maximum(:position).to_i + 1
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
    quest = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Edit me",
      position: @plan.children.maximum(:position).to_i + 1
    )
    quest.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Checklist", scheduled_on: Date.current, position: 0
    )

    patch strategy_goal_path(quest), params: { title: "Edit me", color_key: "coral" }
    assert_equal "coral", quest.reload.color_key

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: quest.id)
    assert_response :success
    assert_select "#climb-path-project-#{quest.id} .lp-climb-path__project.has-color.is-coral"
    assert_select "#climb-path-project-#{quest.id} .lp-climb-path__title", text: /Edit me/
    assert_select "#section-edit-#{quest.id} .lp-color-swatch.is-coral input[checked]"
  end
end
