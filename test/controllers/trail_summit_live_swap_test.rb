# frozen_string_literal: true

require "test_helper"

class TrailSummitLiveSwapTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(character: "fox")
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "Live",
      current_reality: "Building",
      today_mission: "Write tests",
      closer_percent: 20,
      route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_area(@area.id).for_kind("goal").roots.first
    @plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan", title: "Path", position: 0
    )
  end

  def win_all_battles!(project)
    project.children.create!(
      user: @user,
      life_area: @area,
      life_journey: @journey,
      horizon: "day",
      title: "Solo",
      scheduled_on: Date.current,
      position: 0
    ).tap { |battle| battle.update!(completed_at: Time.current) }
  end

  def finish_all_camps!(titles)
    titles.map.with_index do |title, index|
      camp = @user.strategy_goals.create!(
        life_area: @area, life_journey: @journey, parent: @plan, horizon: "project",
        title: title, position: index, stage: index
      )
      win_all_battles!(camp)
      camp.complete!
      camp
    end
  end

  test "finish last camp streams summit world" do
    camp = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "Only", position: 0, stage: 0
    )
    win_all_battles!(camp)

    post strategy_goal_manual_completion_path(camp), as: :turbo_stream
    assert_response :success
    assert_match %(target="trail-mountain-world"), response.body
    assert_match %(action="update_mountain_trail_root"), response.body
    assert_match "lp-trail-summit-scene", response.body
    assert_match %(target="trail-dock-anchor"), response.body
    refute_match %(target="trail-map-camps"), response.body
  end

  test "undo finish streams map back and opens camp sheet" do
    camp = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "Only", position: 0, stage: 0
    )
    win_all_battles!(camp)
    post strategy_goal_manual_completion_path(camp), as: :turbo_stream
    assert camp.reload.manually_completed?

    delete strategy_goal_manual_completion_path(camp), as: :turbo_stream
    assert_response :success
    assert_match %(target="trail-mountain-world"), response.body
    assert_match %(action="open_trail_camp"), response.body
    assert_match "trail-map-camps", response.body
    refute_match "lp-trail-summit-scene", response.body
    refute camp.reload.manually_completed?
  end

  test "create camp from summit streams map and opens new camp" do
    finish_all_camps!(%w[Done])
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_select ".lp-trail-summit-scene"

    post strategy_goals_path, params: {
      life_area_id: @area.id,
      life_journey_id: @journey.id,
      parent_id: @plan.id,
      horizon: "project",
      title: "Fresh ridge"
    }, as: :turbo_stream

    assert_response :success
    new_camp = @plan.reload.children.for_kind("project").find_by!(title: "Fresh ridge")
    assert_match %(target="trail-mountain-world"), response.body
    assert_match %(action="open_trail_camp"), response.body
    assert_match "trail-map-camps", response.body
    assert_match "trail-camp-#{new_camp.id}", response.body
    refute_match "lp-trail-summit-scene", response.body
  end

  test "arrange reopen from summit streams map" do
    camps = finish_all_camps!(%w[Alpha Beta])
    camp = camps.first

    post reopen_life_journey_camp_arrangement_path(@journey),
         params: { camp_id: camp.id },
         as: :turbo_stream

    assert_response :success
    assert_match %(target="trail-mountain-world"), response.body
    assert_match "trail-map-camps", response.body
    refute_match "lp-trail-summit-scene", response.body
    assert_nil camp.reload.completed_at
  end

  test "destroy last open camp streams summit" do
    finish_all_camps!(%w[Done])
    extra = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project",
      title: "Extra", position: 99, stage: 99
    )

    delete strategy_goal_path(extra), as: :turbo_stream
    assert_response :success
    assert_match %(target="trail-mountain-world"), response.body
    assert_match "lp-trail-summit-scene", response.body
  end

  test "finish camp with next camp does not replace mountain world" do
    camp_a = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "A", position: 0, stage: 0
    )
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "B", position: 1, stage: 1
    )
    win_all_battles!(camp_a)

    post strategy_goal_manual_completion_path(camp_a), as: :turbo_stream
    assert_response :success
    assert_match %(target="trail-map-camps"), response.body
    refute_match %(action="update_mountain_trail_root"), response.body
    refute_match %(target="trail-mountain-world"), response.body
  end
end
