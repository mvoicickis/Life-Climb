# frozen_string_literal: true

require "test_helper"

class MountainProjectListTest < ActionDispatch::IntegrationTest
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

  test "nil colour has no colour class; tagged project paints has-color" do
    purple = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Purple Volume", position: 0, color_key: "purple"
    )
    plain = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Plain Volume", position: 1
    )

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select "#climb-path-project-#{purple.id} .lp-climb-path__project.has-color.is-purple"
    assert_select "#climb-path-project-#{plain.id} .lp-climb-path__project.has-color", count: 0
    assert_select "#climb-path-project-#{plain.id} .lp-climb-path__project"
  end

  test "quantified project shows a bar; battle counts never get a bar or ratio" do
    quant = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Save 600", position: 0,
      target_amount: 600, unit: "€", current_amount: 340
    )
    battles = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Job hunt", position: 1
    )
    3.times do |i|
      day = battles.children.create!(
        user: @user, life_area: @area, life_journey: @journey,
        horizon: "day", title: "Battle #{i}", scheduled_on: Date.current, position: i
      )
      day.update_columns(completed_at: Time.current) if i < 2
    end

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select "#climb-path-project-#{quant.id} .lp-climb-path__track"
    assert_select "#climb-path-project-#{quant.id} .lp-climb-path__meta", text: /340 \/ 600/
    assert_select "#climb-path-project-#{battles.id} .lp-climb-path__meta", text: /2 battles won/
    assert_select "#climb-path-project-#{battles.id} .lp-climb-path__track", count: 0
    assert_select "#climb-path-project-#{battles.id}", text: /of \d+/, count: 0
  end

  test "planned battles count up when none are won" do
    camp = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Read funds", position: 0
    )
    camp.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Open a book", scheduled_on: Date.current, position: 0
    )

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select "#climb-path-project-#{camp.id} .lp-climb-path__meta", text: /1 battles planned/
    assert_select "#climb-path-project-#{camp.id} .lp-climb-path__track", count: 0
  end

  test "empty path shows an invitation not a warning" do
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select ".lp-climb-path.is-empty #climb-path-empty", text: /Add a project to this path/
    assert_select ".lp-climb-path__invite", text: /Add a project/
  end

  test "turbo stream create appends a project row" do
    assert_difference -> { @plan.children.where(horizon: "project").count }, 1 do
      post strategy_goals_path,
           params: {
             life_area_id: @area.id,
             life_journey_id: @journey.id,
             parent_id: @plan.id,
             horizon: "project",
             title: "Ship landing"
           },
           as: :turbo_stream
    end
    assert_equal Mime[:turbo_stream].to_s, response.media_type
    assert_includes response.body, "Ship landing"
    assert_includes response.body, "climb-path-projects"
    created = @user.strategy_goals.for_kind("project").find_by!(title: "Ship landing")
    assert_includes response.body, "climb-path-project-#{created.id}"
  end

  test "objectives sheet still creates a quest objective" do
    camp = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Resume", position: 0
    )

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select "#climb-path-project-#{camp.id} [data-action='click->plan-card-menu#objectives']"
    assert_select "#climb-path-project-#{camp.id} turbo-frame#project_objectives_#{camp.id}[data-src=?]",
                  objectives_strategy_goal_path(camp)

    get objectives_strategy_goal_path(camp)
    assert_response :success
    host = camp.children.for_kind("day").find_by!(title: Strategy::EnsureFolderQuest::HOST_TITLE)
    assert_select ".lp-climb-path__quest-add-input"
    assert_select ".lp-climb-path__quest-add-btn", text: /\AAdd\z/

    assert_difference -> { host.practice_tasks.count }, 1 do
      post strategy_goal_practice_tasks_path(host), params: { title: "Rewrite summary" }
    end
    assert host.practice_tasks.exists?(title: "Rewrite summary")
  end
end
