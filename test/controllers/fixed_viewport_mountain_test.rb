# frozen_string_literal: true

require "test_helper"

class FixedViewportMountainTest < ActionDispatch::IntegrationTest
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

  test "mountain uses fixed-viewport planning shell" do
    project = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Resume", position: 0
    )
    project_leaf = practice_leaf_for!(project)
    project_leaf.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Update CV", scheduled_on: Date.current, position: 0
    )

    get life_journey_path(@journey, focus_id: project_leaf.id)
    assert_response :success
    assert_select ".lp-rpg.is-focus-phase"
    assert_select ".lp-rpg__chrome-top"
    assert_select ".lp-rpg__stage.is-planning"
    assert_select ".lp-rpg__planning"
    assert_select ".lp-rpg__stage-trail.is-glance"
    assert_select ".lp-rpg__stage-battle"
    assert_select ".lp-rpg__chrome-bottom"
    assert_select ".lp-rpg-sheet.is-planning"
    assert_select ".lp-rpg-current-path"
    assert_select "[data-controller='category-focus']"
    assert_select ".lp-rpg-todays-practice"
    assert_select ".lp-rpg-context", count: 0
  end

  test "trail window controls appear only when more than three camps exist" do
    5.times do |i|
      camp = @plan.children.create!(
        user: @user, life_area: @area, life_journey: @journey,
        horizon: "project", title: "Camp #{i}", position: i
      )
      camp.complete! if i < 2
    end

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @plan.id)
    assert_response :success
    assert_select "[data-trail-window-target='node']", count: 5
    assert_select ".lp-rpg-trail__shift.is-prev"
    assert_select ".lp-rpg-trail__shift.is-next"
    assert_match(/you are here/i, response.body)
  end

  test "trail window controls stay absent when three or fewer camps" do
    2.times do |i|
      @plan.children.create!(
        user: @user, life_area: @area, life_journey: @journey,
        horizon: "project", title: "Camp #{i}", position: i
      )
    end

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @plan.id)
    assert_response :success
    assert_select "[data-trail-window-target='node']", count: 2
    # With three or fewer camps the window does not need a previous shift.
    assert_select ".lp-rpg-trail__shift.is-prev", count: 0
  end

  test "planning center de-dupes progress and never exposes battle win" do
    project = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Daily battles", position: 0
    )
    project_leaf = practice_leaf_for!(project)
    project_leaf.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Design battle card",
      description: "Sketch the card layout",
      scheduled_on: Date.current, position: 0
    )
    @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Side path", position: 1
    )

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: project_leaf.id)
    assert_response :success

    assert_select ".lp-rpg-summit", minimum: 1
    assert_select ".lp-rpg-stat.is-mountain", count: 0
    assert_select ".lp-rpg-sheet__cue", count: 0
    assert_no_match(/battle_wins|battle_win/, response.body)
    assert_select "form[action*='battle_win']", count: 0

    assert_select ".lp-rpg-path.is-focus .lp-rpg-path__pct", minimum: 1
    assert_select ".lp-rpg-plan-rail__item:not(.is-focus):not(.is-add) .lp-rpg-path__pct", count: 0

    assert_select "[data-controller='category-focus']", minimum: 1
    assert_select ".lp-rpg-practice-focus.is-entered .lp-rpg-practice-focus__title", text: /Steps/i
    assert_select ".lp-rpg-practice-focus.is-entered .lp-rpg-practice-row__title", text: /Design battle card/i
    assert_select ".lp-rpg-todays-practice__kicker", text: /Today's Practice/i
    assert_select ".lp-rpg-practice-focus__cta", text: /Open in Today/i
    assert_select ".lp-rpg-practice-focus__cta[href='#{dashboard_path}']"
    assert_select ".lp-rpg-practice-add", text: /Add Practice/i
    assert_select ".lp-rpg-current-path__crumb", text: /Daily battles/
    assert_select ".lp-rpg-node.is-slot-focus .lp-rpg-node__chip.is-actions"
    assert_select ".lp-rpg-node.is-slot-focus .lp-rpg-node__action.is-edit"
    assert_select ".lp-rpg-node.is-slot-focus .lp-rpg-node__add[data-controller='floating-create']"
    assert_select ".lp-rpg-node.is-slot-focus .lp-rpg-float-create__card"
    assert_select ".lp-rpg-node.is-slot-focus .lp-rpg-float-create__input[name='title']"
    assert_select ".lp-rpg-node.is-slot-focus .lp-rpg-float-create__textarea[name='description']"
    assert_select ".lp-rpg-node.is-slot-focus .lp-rpg-float-create__btn.is-create"
    assert_select ".lp-rpg-node.is-slot-focus form.lp-rpg-node__add-form[action='/strategy_goals']"
  end
end
