# frozen_string_literal: true

require "test_helper"

class QuestFolderCreateReproduceTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user, area_key: "career", title: "Find a job",
      ideal_scene: "Hired", current_reality: "Searching", next_win: "Interview",
      today_mission: "Apply", closer_percent: 20, route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Find a job", position: 0
    )
    @camp = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Learn German", position: 0
    )
  end

  test "empty path camp does not render nested New Quest form" do
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp.id)
    assert_response :success
    assert_select ".lp-climb-path__new-quest-btn", count: 0
    assert_select ".lp-qs-new__btn", count: 0
  end

  test "HTML create nested quest is rejected" do
    assert_no_difference -> { @camp.children.where(horizon: "project").count } do
      post strategy_goals_path, params: {
        life_area_id: @area.id, life_journey_id: @journey.id,
        parent_id: @camp.id, horizon: "project", title: "Vocabulary"
      }
    end
    assert_response :redirect
    assert_nil @camp.children.find_by(title: "Vocabulary")
  end

  test "turbo_stream create nested quest is rejected" do
    assert_no_difference -> { @camp.children.where(horizon: "project").count } do
      post strategy_goals_path,
           params: {
             life_area_id: @area.id, life_journey_id: @journey.id,
             parent_id: @camp.id, horizon: "project", title: "Grammar"
           },
           as: :turbo_stream
    end
    assert_response :redirect
    assert_nil @camp.children.find_by(title: "Grammar")
  end
end
