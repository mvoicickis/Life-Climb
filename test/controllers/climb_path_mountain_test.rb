# frozen_string_literal: true

require "test_helper"

class ClimbPathMountainTest < ActionDispatch::IntegrationTest
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
  end

  test "climb path caps locked nodes at three and keeps all done plus current" do
    8.times do |i|
      camp = @plan.children.create!(
        user: @user, life_area: @area, life_journey: @journey,
        horizon: "project", title: "Camp #{i}", position: i
      )
      camp.complete! if i < 2
    end

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select ".lp-climb-path"
    assert_select ".lp-climb-path__node.is-done", count: 2
    assert_select ".lp-climb-path__node.is-current", count: 1
    assert_select ".lp-climb-path__node.is-locked", count: 3
    assert_select ".lp-climb-path__node.is-locked", text: /Camp 7/, count: 0
    assert_select ".lp-climb-path__face[src*='fox']", minimum: 1
  end

  test "current and done climb nodes keep turbo focus links" do
    first = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Cleared camp", position: 0
    )
    first.complete!
    current = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Active camp", position: 1
    )
    @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Fogged camp", position: 2
    )

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: current.id)
    assert_response :success
    assert_select ".lp-climb-path__node.is-done a.lp-climb-path__link[href*='focus_id=#{first.id}']"
    assert_select ".lp-climb-path__node.is-current a.lp-climb-path__link[href*='focus_id=#{current.id}']"
    assert_select ".lp-climb-path__node.is-locked a.lp-climb-path__link", count: 0
  end
end
