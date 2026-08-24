# frozen_string_literal: true

require "test_helper"

class MountainTrailTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    allow_extra_climbs!(@user)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Write tests",
      closer_percent: 20
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      horizon: "goal", title: "Trail summit"
    }
    @goal = @user.strategy_goals.for_kind("goal").last
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: @goal.id, horizon: "plan", title: "Main path"
    }
    @plan = @user.strategy_goals.for_kind("plan").last
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: @plan.id, horizon: "project", title: "Base camp",
      color_key: "teal", trail_x: 0.48, trail_y: 0.72
    }
    @project = @user.strategy_goals.for_kind("project").last
  end

  test "mountain show renders V4 trail canvas with camps and hides holding" do
    holding_plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal,
      horizon: "plan", title: "Hold", position: 99, holding: true
    )
    holding = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: holding_plan,
      horizon: "project", title: "Secret hold", position: 0, holding: true
    )

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select "#mountain-trail"
    assert_select "#trail-camps"
    assert_select "#trail-camp-#{@project.id}", text: /Base camp/
    assert_select "#trail-camp-#{holding.id}", count: 0
    assert_select ".lp-trail-hud"
    assert_select ".lp-trail-segments"
    assert_select ".lp-dash-nav.is-v4 .lp-dash-nav__fab"
    assert_select ".lp-rpg-scenic", count: 0
    assert_match(/mountain_trail_default|mountain_photo/, response.body)
  end

  test "mountain v4 phone includes cream tabs journey and today card hooks" do
    @project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Pitch the tent", scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select ".lp-dash-nav.is-v4 a[href='#{life_points_path}']"
    assert_select ".lp-dash-nav.is-v4 a[href='#{dashboard_path}']"
    assert_select ".lp-trail__peak"
    assert_select ".lp-trail-base"
  end

  test "planting a project via turbo stream appends a trail camp" do
    assert_difference -> { @plan.children.for_kind("project").count }, 1 do
      post strategy_goals_path, params: {
        life_area_id: @area.id,
        life_journey_id: @journey.id,
        parent_id: @plan.id,
        horizon: "project",
        title: "Ridge camp",
        trail_x: 0.52,
        trail_y: 0.44,
        color_key: "amber"
      }, as: :turbo_stream
    end
    assert_equal Mime[:turbo_stream].to_s, response.media_type
    created = @plan.children.for_kind("project").find_by!(title: "Ridge camp")
    assert_includes response.body, "trail-camps"
    assert_includes response.body, "trail-camp-#{created.id}"
    assert_in_delta 0.52, created.trail_x, 0.0001
  end

  test "camp sheet lists day battles and win forms" do
    battle = @project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Pack the tent", scheduled_on: Date.current, position: 0
    )

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select "#trail-sheet-camp-#{@project.id}"
    assert_select "#trail-battles-#{@project.id} #trail-battle-#{battle.id}", text: /Pack the tent/
    assert_select "#trail-battles-#{@project.id} form[action*='battle_win']"
  end

  test "upload and reset mountain photo" do
    photo = fixture_file_upload("mountain_trail_default.jpg", "image/jpeg")

    patch life_journey_path(@journey), params: {
      mountain_photo_intent: "upload",
      life_journey: { mountain_photo: photo }
    }
    assert_redirected_to life_journey_path(@journey)
    assert @journey.reload.mountain_photo.attached?

    # Sync purge in test (controller uses purge_later).
    perform_enqueued_jobs do
      patch life_journey_path(@journey), params: { mountain_photo_intent: "reset" }
    end
    assert_redirected_to life_journey_path(@journey)
    assert_not @journey.reload.mountain_photo.attached?
  end
end
