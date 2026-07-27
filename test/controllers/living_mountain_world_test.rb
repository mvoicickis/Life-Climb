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

  test "mountain opens as a full-bleed living world with minimal HUD" do
    get life_journey_path(@journey)
    assert_response :success
    assert_select ".lp-world.is-living-world"
    assert_select ".lp-world-hud"
    assert_select ".lp-world-hud__chip.is-ap"
    assert_select ".lp-world-hud__chip.is-sp"
    assert_select ".lp-world-hud__gear"
    assert_select ".lp-strategy-page__title", count: 0
    assert_select ".lp-strategy-crumb", count: 0
    assert_select "[data-controller*=strategy-camera]"
  end

  test "creating a plan via turbo stream refreshes the world map" do
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
    assert_match(/strategy-world-map/, response.body)
    assert_match(/Trail Plan/, response.body)
    assert_match(/strategy-menu-/, response.body)
  end

  test "project overflow chip appears instead of stacking pins" do
    plan = @goal.children.create!(
      user: @user,
      life_area: @area,
      life_journey: @journey,
      horizon: "plan",
      title: "Main trail",
      position: 0
    )
    4.times do |i|
      plan.children.create!(
        user: @user,
        life_area: @area,
        life_journey: @journey,
        horizon: "project",
        title: "Project #{i + 1}",
        position: i
      )
    end

    get life_journey_path(@journey, focus_id: plan.id)
    assert_response :success
    assert_select ".lp-strategy-overflow.is-project", text: "+1 more"
    assert_select ".lp-strategy-mountain__slot.is-project", maximum: 3
  end

  test "L1 keeps projects on layer 2 for camera zoom" do
    plan = @goal.children.create!(
      user: @user,
      life_area: @area,
      life_journey: @journey,
      horizon: "plan",
      title: "Main trail",
      position: 0
    )
    project = plan.children.create!(
      user: @user,
      life_area: @area,
      life_journey: @journey,
      horizon: "project",
      title: "First climb",
      position: 0
    )

    get life_journey_path(@journey)
    assert_response :success
    assert_select %([data-camera-layer="1"][data-camera-plan-id="#{plan.id}"])
    assert_select %([data-camera-layer="2"][data-camera-project-id="#{project.id}"])
  end
end
