# frozen_string_literal: true

require "test_helper"

class LivingMountainWorldTest < ActionDispatch::IntegrationTest
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
  end

  test "mountain opens first-climb coach when spine is empty" do
    get life_journey_path(@journey)
    assert_response :success
    assert_select ".lp-rpg.is-first-climb"
    assert_select "#first-climb-coach"
    assert_select ".lp-rpg-glass", count: 0
  end

  test "mountain opens as cinematic RPG world once a plan exists" do
    @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Main trail", position: 0
    )

    get life_journey_path(@journey)
    assert_response :success
    assert_select ".lp-rpg"
    assert_select ".lp-rpg-world"
    assert_select ".lp-rpg-plan", text: /Main trail/i
    assert_select "[data-controller*=strategy-rpg]"
  end

  test "resting mountain shows plan checkpoints on the trail" do
    plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Main trail", position: 0
    )
    project = plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "First climb", position: 0
    )
    project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Battle one", scheduled_on: Date.current, position: 0
    )

    get life_journey_path(@journey)
    assert_response :success
    assert_select ".lp-rpg-plan", minimum: 1
    assert_select ".lp-rpg-glass"
  end

  test "focusing a plan shows missions and battle counts in glass" do
    plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Find Job", position: 0
    )
    project = plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Resume", position: 0
    )
    2.times do |i|
      project.children.create!(
        user: @user, life_area: @area, life_journey: @journey,
        horizon: "day", title: "Battle #{i}", scheduled_on: Date.current, position: i
      )
    end

    get life_journey_path(@journey, focus_id: plan.id)
    assert_response :success
    assert_select ".lp-rpg-mission", text: /Resume/
    assert_select ".lp-rpg-mission__meta", text: /2 battles/i
    assert_select ".lp-rpg-panel.is-projects .lp-rpg-add", text: /Add project/i
  end

  test "focusing a project shows battles in glass" do
    plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Find Job", position: 0
    )
    project = plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Resume", position: 0
    )
    project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Update CV", scheduled_on: Date.current, position: 0
    )

    get life_journey_path(@journey, focus_id: project.id)
    assert_response :success
    assert_select ".lp-rpg-mission.is-focus", text: /Resume/
    assert_select ".lp-rpg-battle", text: /Update CV/
    assert_select ".lp-rpg-panel.is-battles .lp-rpg-add", text: /Add battle/i
  end

  test "creating a plan via turbo stream still succeeds" do
    post strategy_goals_path,
         params: {
           life_area_id: @area.id,
           life_journey_id: @journey.id,
           parent_id: @goal.id,
           horizon: "plan",
           title: "Trail Plan"
         },
         as: :turbo_stream

    assert_response :created
    assert @user.strategy_goals.for_kind("plan").exists?(title: "Trail Plan")
  end
end
