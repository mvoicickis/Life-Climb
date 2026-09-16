# frozen_string_literal: true

require "test_helper"

class CampArrangementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(planning_version: 2)
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
      horizon: "goal", title: "Summit"
    }
    @goal = @user.strategy_goals.find_by!(horizon: "goal", title: "Summit")
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: @goal.id, horizon: "plan", title: "Path"
    }
    @plan = @goal.children.find_by!(horizon: "plan", title: "Path")
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: @plan.id, horizon: "project", title: "Camp A"
    }
    @camp_a = @plan.children.find_by!(horizon: "project", title: "Camp A")
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: @plan.id, horizon: "project", title: "Camp B"
    }
    @camp_b = @plan.children.find_by!(horizon: "project", title: "Camp B")
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: @plan.id, horizon: "project", title: "Camp C"
    }
    @camp_c = @plan.children.find_by!(horizon: "project", title: "Camp C")
  end

  test "update reorders camps and returns turbo stream" do
    patch life_journey_camp_arrangement_path(@journey),
          params: {
            plan_id: @plan.id,
            "groups[0][camp_ids][]" => @camp_b.id,
            "groups[1][camp_ids][]" => @camp_a.id,
            "groups[2][camp_ids][]" => @camp_c.id
          },
          as: :turbo_stream

    assert_response :success
    assert_match(/turbo-stream/, response.body)
    assert_match("trail-map-camps", response.body)
    assert_equal 0, @camp_b.reload.stage
    assert_equal 1, @camp_a.reload.stage
    assert_equal 2, @camp_c.reload.stage
    assert_equal 0, @camp_b.position
    assert_equal 1, @camp_a.position
    assert_equal 2, @camp_c.position
  end

  test "update merges camp into existing stage" do
    @camp_a.update_columns(stage: 0, position: 0)
    @camp_b.update_columns(stage: 1, position: 1)
    @camp_c.update_columns(stage: 2, position: 2)

    patch life_journey_camp_arrangement_path(@journey),
          params: {
            plan_id: @plan.id,
            groups: {
              "0" => { camp_ids: [ @camp_a.id, @camp_b.id ] },
              "1" => { camp_ids: [ @camp_c.id ] }
            }
          },
          as: :turbo_stream

    assert_response :success
    assert_match("trail-arrange-camps", response.body)
    assert_equal 0, @camp_a.reload.stage
    assert_equal 0, @camp_b.reload.stage
    assert_equal 1, @camp_c.reload.stage
    assert_equal 0, @camp_a.position
    assert_equal 1, @camp_b.position
    assert_equal 2, @camp_c.position
  end

  test "update appends camp as new trailing stage" do
    @camp_a.update_columns(stage: 0, position: 0)
    @camp_b.update_columns(stage: 1, position: 1)
    @camp_c.update_columns(stage: 2, position: 2)

    patch life_journey_camp_arrangement_path(@journey),
          params: {
            plan_id: @plan.id,
            groups: {
              "0" => { camp_ids: [ @camp_a.id ] },
              "1" => { camp_ids: [ @camp_c.id ] },
              "2" => { camp_ids: [ @camp_b.id ] }
            }
          },
          as: :turbo_stream

    assert_response :success
    assert_match("trail-arrange-camps", response.body)
    assert_equal 0, @camp_a.reload.stage
    assert_equal 1, @camp_c.reload.stage
    assert_equal 2, @camp_b.reload.stage
    assert_equal 0, @camp_a.position
    assert_equal 1, @camp_c.position
    assert_equal 2, @camp_b.position
  end

  test "update rejects invalid payload" do
    patch life_journey_camp_arrangement_path(@journey),
          params: { plan_id: @plan.id, groups: [ { camp_ids: [ @camp_a.id ] } ] },
          as: :json

    assert_response :unprocessable_entity
  end
end
