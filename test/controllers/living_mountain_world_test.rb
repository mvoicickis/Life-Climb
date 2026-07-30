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
    assert_select ".lp-rpg-path", text: /Main trail/i
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
    assert_select ".lp-rpg-path", minimum: 1
    assert_select ".lp-rpg-trail"
    assert_select ".lp-rpg-node", text: /First climb/
    assert_select ".lp-rpg-sheet"
  end

  test "focusing a plan shows trail checkpoints and battle sheet" do
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
    assert_select ".lp-rpg-node.is-current", text: /Resume/
    assert_select ".lp-rpg-sheet__title", text: /Resume/
    assert_select ".lp-rpg-battle", minimum: 1
    assert_select ".lp-rpg-add.is-checkpoint", text: /Checkpoint|project/i
  end

  test "focusing a project shows battles in the sheet" do
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
    assert_select ".lp-rpg-node.is-current", text: /Resume/
    assert_select ".lp-rpg-sheet__title", text: /Resume/
    assert_select ".lp-rpg-battle", text: /Update CV/
    assert_select ".lp-rpg-sheet .lp-rpg-add", text: /Step|battle/i
  end

  test "locked trail nodes cannot become the active focus" do
    plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Find Job", position: 0
    )
    first = plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Resume", position: 0
    )
    locked = plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Interviews", position: 1
    )
    first.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Update CV", scheduled_on: Date.current, position: 0
    )

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: plan.id, focus_id: locked.id)
    assert_response :success
    assert_select ".lp-rpg-node.is-current", text: /Resume/
    assert_select ".lp-rpg-sheet__title", text: /Resume/
    assert_select ".lp-rpg-node.is-locked", text: /Interviews/
  end

  test "plan rail keeps multiple paths with snap track and overflow arrows" do
    @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Path Alpha", position: 0
    )
    @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Path Beta", position: 1
    )
    @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Path Gamma", position: 2
    )

    get life_journey_path(@journey)
    assert_response :success
    assert_select ".lp-rpg-plan-rail[data-controller*=strategy-plan-rail]"
    assert_select ".lp-rpg-plan-rail__track[data-strategy-plan-rail-target=track]"
    assert_select ".lp-rpg-plan-rail__item", minimum: 3
    assert_select ".lp-rpg-path", text: /Path Alpha/
    assert_select ".lp-rpg-path", text: /Path Beta/
    assert_select ".lp-rpg-path", text: /Path Gamma/
    assert_select ".lp-rpg-plan-rail__arrow.is-prev[data-strategy-plan-rail-target=prev]"
    assert_select ".lp-rpg-plan-rail__arrow.is-next[data-strategy-plan-rail-target=next]"
  end

  test "goal_id and plan_id switch the climb" do
    other_goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Health", position: 1
    )
    plan_a = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Career path", position: 0
    )
    plan_b = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Side path", position: 1
    )
    plan_a.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Resume camp", position: 0
    )
    plan_b.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Launch camp", position: 0
    )
    other_goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Run path", position: 0
    ).children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "5k camp", position: 0
    )

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: plan_b.id)
    assert_response :success
    assert_select ".lp-rpg-path.is-focus", text: /Side path/
    assert_select ".lp-rpg-node", text: /Launch camp/
    assert_select ".lp-rpg-goal.is-focus", text: /#{@goal.title}/

    get life_journey_path(@journey, goal_id: other_goal.id)
    assert_response :success
    assert_select ".lp-rpg-goal.is-focus", text: /Health/
    assert_select ".lp-rpg-path", text: /Run path/
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
