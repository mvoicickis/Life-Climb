# frozen_string_literal: true

require "test_helper"

class ClimbPathPolishMountainTest < ActionDispatch::IntegrationTest
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
    @user.update!(
      support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ],
      character: "fox"
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Main trail", position: 0
    )
    @done = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Cleared", position: 0
    )
    @done.complete!
    @current = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Active", position: 1
    )
    @locked = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Fogged", position: 2
    )
  end

  test "climb path nodes expose node target; playable links wire tap haptic" do
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @current.id)
    assert_response :success

    assert_select ".lp-climb-path__node[data-climb-path-target*='node']", minimum: 3
    assert_select ".lp-climb-path__node.is-done a.lp-climb-path__link[data-action*='climb-path#tap']"
    assert_select ".lp-climb-path__node.is-current a.lp-climb-path__link[data-action*='climb-path#tap']"
    assert_select ".lp-climb-path__node.is-locked a.lp-climb-path__link[data-action*='climb-path#tap']", count: 0
    assert_select ".lp-climb-path__node.is-locked .lp-climb-path__link.is-static"
  end
end
