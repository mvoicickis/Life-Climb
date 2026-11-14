# frozen_string_literal: true

require "test_helper"

class EmptyGoalRepairTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(planning_version: 2, onboarding_completed_at: Time.current)
    sign_in_as @user
    allow_extra_climbs!(@user)

    area = LifeAreas::Select.call(user: @user, keys: [ "career" ]).first
    @journey = Journeys::Create.call(
      user: @user,
      life_area: area,
      title: "Life Climb",
      ideal_scene: "App live",
      current_reality: "Older journey with no spine",
      next_win: nil,
      closer_percent: 5
    )
    Focus::SetJourneys.call(user: @user, journey_ids: [ @journey.id ])
    @user.strategy_goals.where(life_journey_id: @journey.id).delete_all
  end

  test "mountain with no root goal opens destination coach and prefills journey title" do
    assert_nil Goals::Current.goal_for(user: @user, journey: @journey)

    get life_journey_path(@journey)
    assert_response :success
    assert_select ".lp-rpg-destination[data-destination-switcher-open-on-connect-value='true']"
    assert_select "#destination-coach"
    assert_select "#destination-coach-title[value=?]", "Life Climb"
    assert_select "input[name=return_to][value=mountain]"
    assert_select ".lp-first-climb__title", text: /Name your mountain/i
    assert_select ".lp-rpg-destination-carousel__title", text: /Name your mountain/i
  end

  test "saving destination coach creates goal on the same journey and lands on mountain" do
    journey_count = @user.life_journeys.count

    assert_difference -> { @user.strategy_goals.for_kind("goal").roots.where(life_journey_id: @journey.id).count }, +1 do
      assert_difference -> { @user.strategy_goals.for_kind("plan").count }, +1 do
        post first_climbs_path, params: {
          life_journey_id: @journey.id,
          title: "Life Climb",
          plan_title: "Ship the trail",
          today_action: "Write one failing test",
          return_to: "mountain"
        }
      end
    end

    assert_equal journey_count, @user.life_journeys.count, "must reuse the open journey, not create another"

    goal = @user.strategy_goals.for_kind("goal").roots.find_by!(life_journey_id: @journey.id, title: "Life Climb")
    plan = goal.children.for_kind("plan").not_holding.first
    assert plan.present?
    assert_redirected_to life_journey_path(@journey, goal_id: goal.id, plan_id: plan.id)

    follow_redirect!
    assert_response :success
    assert_select ".lp-rpg.is-v4-phone"
    assert_select "#mountain-trail"
    assert_select ".lp-trail-destination", count: 0
  end
end
