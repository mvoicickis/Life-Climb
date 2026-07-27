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
    assert_select ".lp-world.is-living-world.is-first-climb"
    assert_select "#first-climb-coach"
    assert_select ".lp-world-hud", count: 0
  end

  test "mountain opens as a full-bleed living world with camp notebook once a plan exists" do
    @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Main trail", position: 0
    )

    get life_journey_path(@journey)
    assert_response :success
    assert_select ".lp-world.is-living-world.is-camp-notebook"
    assert_select ".lp-world-hud"
    assert_select "[data-controller*=strategy-notebook]"
    assert_select ".lp-strategy-page__title", count: 0
  end

  test "resting mountain shows plans but not project or battle pins" do
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
    assert_select ".lp-strategy-marker.is-pin.is-plan", minimum: 1
    assert_select ".lp-strategy-marker.is-pin.is-project", count: 0
    assert_select ".lp-strategy-marker.is-pin.is-battle", count: 0
    assert_select "#strategy-camp-notebook"
  end

  test "focusing a plan opens the camp notebook with projects and battle counts" do
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
    assert_select "#strategy-camp-notebook.is-open"
    assert_select ".lp-camp-notebook__row.is-project", text: /Resume/
    assert_select ".lp-camp-notebook__row-meta", text: /2 battles/i
    assert_select ".lp-camp-notebook__context-add", text: /Add project/i
  end

  test "focusing a project expands battles and shows reactive tent" do
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
    assert_select "#strategy-camp-notebook.is-open"
    assert_select ".lp-camp-notebook__project.is-expanded"
    assert_select ".lp-camp-notebook__battle-title", text: /Update CV/
    assert_select ".lp-strategy-mountain__slot.is-project.is-react:not([hidden])"
    assert_select ".lp-camp-react-tent.is-glow", text: /Resume/
    assert_select ".lp-camp-notebook__context-add", text: /Add battle/i
  end

  test "creating a plan via turbo stream refreshes map and notebook" do
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
    assert_match(/strategy-camp-notebook/, response.body)
    assert_match(/Trail Plan/, response.body)
  end
end
