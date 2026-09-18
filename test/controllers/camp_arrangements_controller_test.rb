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

  test "reopen finished camp returns turbo stream and shows camp in active list" do
    @camp_a.update_columns(stage: 0, position: 0)
    @camp_b.update_columns(stage: 1, position: 1)
    @camp_c.update_columns(stage: 2, position: 2)
    battle = @camp_a.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Won fight", scheduled_on: Date.current, position: 0
    )
    battle.complete!
    @camp_a.complete!
    Strategy::SyncCompletion.call(project: @camp_a)

    post reopen_life_journey_camp_arrangement_path(@journey),
         params: { camp_id: @camp_a.id },
         as: :turbo_stream

    assert_response :success
    assert_match("trail-arrange-camps", response.body)
    assert_match(/data-camp-id="#{@camp_a.id}"/, response.body)
    assert_match(/lp-pointer-reorder__row/, response.body)
    assert_nil @camp_a.reload.completed_at
    assert_equal 1, @camp_a.children.reload.count { |d| d.day? && !d.completed? }
  end

  test "stage_camp adds camp on finished stage" do
    @camp_a.update_columns(stage: 0, position: 0)
    @camp_b.update_columns(stage: 1, position: 1)
    @camp_c.update_columns(stage: 2, position: 2)
    @camp_a.complete!
    Strategy::SyncCompletion.call(project: @camp_a)

    assert_difference -> { @plan.children.for_kind("project").count }, 1 do
      post stage_camp_life_journey_camp_arrangement_path(@journey),
           params: { plan_id: @plan.id, stage: 0, title: "Fresh camp" },
           as: :turbo_stream
    end

    assert_response :success
    created = @plan.children.for_kind("project").find_by!(title: "Fresh camp")
    assert_equal 0, created.stage
    assert_operator created.position, :<, @camp_b.reload.position
    assert_match("Fresh camp", response.body)
    assert_match(/Step 1/, response.body)
    assert_match(/action="before"[^>]*target="trail-arrange-add-camp"/, response.body)
    refute_match(/action="replace"[^>]*target="trail-arrange-camps"/, response.body)
  end

  test "stage_camp with stage last appends new terrace step" do
    @camp_a.update_columns(stage: 0, position: 0)
    @camp_b.update_columns(stage: 1, position: 1)
    @camp_c.update_columns(stage: 2, position: 2)

    assert_difference -> { @plan.children.for_kind("project").count }, 1 do
      post stage_camp_life_journey_camp_arrangement_path(@journey),
           params: { plan_id: @plan.id, stage: "last", title: "Summit camp" },
           as: :turbo_stream
    end

    assert_response :success
    created = @plan.children.for_kind("project").find_by!(title: "Summit camp")
    assert_equal 3, created.stage
    assert_match(/action="before"[^>]*target="trail-arrange-add-camp"/, response.body)
    assert_match("Summit camp", response.body)
    assert_match(/Step 4/, response.body)
    assert_match(/lp-pointer-reorder__handle/, response.body)
    refute_match(/action="replace"[^>]*target="trail-arrange-camps"/, response.body)
  end

  test "update with finished-first current order leaves stage and position unchanged" do
    @camp_a.update_columns(stage: 0, position: 0)
    @camp_b.update_columns(stage: 0, position: 1)
    @camp_c.update_columns(stage: 1, position: 2)
    @camp_a.complete!

    before = {
      a: @camp_a.reload.attributes.slice("stage", "position"),
      b: @camp_b.reload.attributes.slice("stage", "position"),
      c: @camp_c.reload.attributes.slice("stage", "position")
    }

    # Same order UI buildGroups would send: finished first within stage, then active.
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
    assert_equal before[:a], @camp_a.reload.attributes.slice("stage", "position")
    assert_equal before[:b], @camp_b.reload.attributes.slice("stage", "position")
    assert_equal before[:c], @camp_c.reload.attributes.slice("stage", "position")
  end

  test "reopen with another users camp_id returns 404 and changes nothing" do
    other = users(:two)
    other.update!(planning_version: 2)
    allow_extra_climbs!(other)
    other_area = other.life_areas.first || other.life_areas.create!(key: "career", number: 9)
    other_goal = other.strategy_goals.create!(life_area: other_area, horizon: "goal", title: "Other", position: 0)
    other_plan = other.strategy_goals.create!(
      life_area: other_area, parent: other_goal, horizon: "plan", title: "Other plan", position: 0
    )
    foreign = other.strategy_goals.create!(
      life_area: other_area, parent: other_plan, horizon: "project", title: "Foreign", position: 0, stage: 0
    )
    foreign.complete!

    @camp_a.update_columns(stage: 0, position: 0)
    @camp_a.complete!
    before = @camp_a.reload.attributes.slice("completed_at", "stage", "position")

    post reopen_life_journey_camp_arrangement_path(@journey),
         params: { camp_id: foreign.id },
         as: :turbo_stream

    assert_response :not_found
    assert_equal before["completed_at"], @camp_a.reload.completed_at
    assert foreign.reload.completed?
  end
end
