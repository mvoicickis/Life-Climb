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

  test "mountain with no root goal redirects into name step with title prefilled" do
    assert_nil Goals::Current.goal_for(user: @user, journey: @journey)

    get life_journey_path(@journey)
    assert_redirected_to new_life_journey_path(step: "goal", repair: @journey.id)

    follow_redirect!
    assert_response :success
    assert_select "h1", text: I18n.t("v2_onboarding.mountain_name_title")
    assert_select "input#new_goal_mountain_name[value=?]", "Life Climb"
    assert_select "input[type=radio][name=ring][value=work_money][checked]"
    assert_select "input[type=hidden][name=repair][value=?]", @journey.id.to_s
    assert_select "a.lp-ob__back[href=?]", new_life_journey_path(cancel_repair: 1)
    assert_select "#destination-coach", count: 0
  end

  test "submitting camps creates spine on the same journey" do
    journey_count = @user.life_journeys.count

    get life_journey_path(@journey)
    follow_redirect!

    post life_journeys_path(step: "goal"), params: {
      ring: "work_money",
      repair: @journey.id,
      onboarding: { goal: "Life Climb" }
    }
    assert_redirected_to new_life_journey_path(step: "camps", repair: @journey.id)

    assert_difference -> { @user.strategy_goals.for_kind("goal").roots.where(life_journey_id: @journey.id).count }, +1 do
      assert_difference -> { @user.strategy_goals.for_kind("plan").where(life_journey_id: @journey.id).count }, +1 do
        assert_difference -> { @user.strategy_goals.for_kind("project").where(life_journey_id: @journey.id).count }, +2 do
          assert_no_difference -> { @user.life_journeys.count } do
            post life_journeys_path(step: "camps"), params: {
              ring: "work_money",
              repair: @journey.id,
              onboarding: { camp_titles: [ "Ship trail", "Open beta" ] }
            }
          end
        end
      end
    end

    assert_equal journey_count, @user.life_journeys.count
    assert_redirected_to life_journey_path(@journey)

    goal = @user.strategy_goals.for_kind("goal").roots.find_by!(life_journey_id: @journey.id, title: "Life Climb")
    plan = goal.children.for_kind("plan").not_holding.first
    assert plan.present?
    camps = plan.children.for_kind("project").not_holding.order(:position)
    assert_equal [ "Ship trail", "Open beta" ], camps.map(&:title)
    assert_equal "Life Climb", @journey.reload.title

    follow_redirect!
    assert_response :success
    assert_select ".lp-rpg.is-v4-phone"
  end

  test "second camps submit creates nothing when root goal already exists" do
    Onboarding::ClimbSpine.call(
      user: @user,
      goal_title: "Life Climb",
      camp_titles: [ "Ship trail" ],
      journey: @journey,
      seed_battle: false,
      celebrate_goal: false,
      include_bootstrap_flag: false,
      first_camp_reveal_status: "done"
    )

    # Name step still accepts repair for an owned journey; camps must no-op.
    post life_journeys_path(step: "goal"), params: {
      ring: "work_money",
      repair: @journey.id,
      onboarding: { goal: "Life Climb" }
    }
    assert_redirected_to new_life_journey_path(step: "camps", repair: @journey.id)

    goal_count = @user.strategy_goals.for_kind("goal").roots.where(life_journey_id: @journey.id).count
    plan_count = @user.strategy_goals.for_kind("plan").where(life_journey_id: @journey.id).count
    journey_count = @user.life_journeys.count
    assert_equal 1, goal_count

    post life_journeys_path(step: "camps"), params: {
      ring: "work_money",
      repair: @journey.id,
      onboarding: { camp_titles: [ "Another camp" ] }
    }

    assert_redirected_to life_journey_path(@journey)
    assert_equal goal_count, @user.strategy_goals.for_kind("goal").roots.where(life_journey_id: @journey.id).count
    assert_equal plan_count, @user.strategy_goals.for_kind("plan").where(life_journey_id: @journey.id).count
    assert_equal journey_count, @user.life_journeys.count
  end

  test "another users journey id is refused" do
    other = users(:two)
    other_area = LifeAreas::Select.call(user: other, keys: [ "career" ]).first
    foreign = Journeys::Create.call(
      user: other,
      life_area: other_area,
      title: "Foreign climb",
      ideal_scene: "Elsewhere",
      current_reality: "Not yours",
      next_win: nil,
      closer_percent: 5
    )

    get world_path
    session[LifeJourneysController::NEW_GOAL_SESSION_KEY] = {
      "user_id" => @user.id,
      "ring" => "work_money",
      "goal" => "Life Climb",
      "camp_titles" => [ "Ship trail" ],
      "repair_journey_id" => foreign.id
    }

    journey_count = @user.life_journeys.count
    assert_no_difference -> { @user.strategy_goals.for_kind("goal").roots.count } do
      assert_no_difference -> { other.strategy_goals.for_kind("goal").roots.count } do
        post life_journeys_path(step: "camps"), params: {
          ring: "work_money",
          repair: foreign.id,
          onboarding: { camp_titles: [ "Ship trail" ] }
        }
      end
    end

    assert_redirected_to world_path
    assert_equal journey_count, @user.life_journeys.count
    assert_nil @user.strategy_goals.for_kind("goal").roots.find_by(life_journey_id: @journey.id)
  end

  test "cancel repair returns to my world" do
    get life_journey_path(@journey)
    follow_redirect!

    get new_life_journey_path(cancel_repair: 1)
    assert_redirected_to world_path
    assert_nil session[LifeJourneysController::NEW_GOAL_SESSION_KEY]
  end
end
