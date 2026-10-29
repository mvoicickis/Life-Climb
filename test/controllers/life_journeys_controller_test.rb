# frozen_string_literal: true

require "test_helper"

class LifeJourneysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(planning_version: 2, onboarding_completed_at: Time.current)
    sign_in_as @user
    allow_extra_climbs!(@user)
  end

  test "new shows seven creatable rings and hides infinity" do
    @user.life_areas.where(dream_id: nil).update_all(selected_at: nil)
    @user.update!(character: "fox", support_milestones_shown: [ User::COMPANION_PICK_KEY, User::ADVENTURE_GUIDE_KEY ])

    get new_life_journey_path
    assert_response :success
    assert_select ".ring-picker__title", text: I18n.t("my_world.rings.pick_title")
    LifeArea.creatable_world_rings.each do |ring|
      assert_select "input[type=radio][name=ring][value=?]", ring
      assert_select ".ring-picker__name", text: I18n.t("my_world.rings.#{ring}.name")
    end
    assert_select "input[type=radio][name=ring][value=infinity]", count: 0
    assert_select ".ring-picker__name", text: I18n.t("my_world.rings.infinity.name"), count: 0
    assert_select "h1", text: I18n.t("v2_onboarding.mountain_name_title")
    assert_select "input#new_goal_mountain_name"
    assert_select "input[type=submit][value=?]", I18n.t("journeys.next")
    assert_select "textarea#life_journey_ideal_scene", count: 0
    assert_select "textarea#life_journey_current_reality", count: 0
  end

  test "new preselects ring from query and does not redirect without selected areas" do
    @user.life_areas.where(dream_id: nil).update_all(selected_at: nil)

    get new_life_journey_path(ring: "family_love")
    assert_response :success
    assert_select "input[type=radio][name=ring][value=family_love][checked]"
    assert_select "input[type=radio][name=ring][value=me]:not([checked])"
  end

  test "full flow ring name camps builds spine focuses and opens v4 mountain" do
    older = seed_climb!(@user, area_key: "career", title: "Career climb", today_mission: "Ship one")
    assert_equal "active", older.status
    assert_equal 1, older.focus_position
    completed_at = @user.onboarding_completed_at
    older_flags = older.setup_flags.deep_dup

    assert_no_difference -> { @user.life_journeys.count } do
      post life_journeys_path(step: "goal"), params: {
        ring: "family_love",
        onboarding: { goal: "Weekly family dinner" }
      }
    end
    assert_redirected_to new_life_journey_path(step: "camps")

    follow_redirect!
    assert_response :success
    assert_select "h1", text: I18n.t("v2_onboarding.camps_title")
    assert_select ".lp-ob__goal-echo", text: "Weekly family dinner"
    assert_select "input[type=submit][value=?]", I18n.t("journeys.start_climb")

    assert_difference -> { @user.life_journeys.count }, 1 do
      post life_journeys_path(step: "camps"), params: {
        ring: "family_love",
        onboarding: { camp_titles: [ "Pick a night", "Cook together" ] }
      }
    end

    journey = @user.life_journeys.order(:id).last
    assert_redirected_to life_journey_path(journey)
    assert_equal "relationships", journey.life_area.key
    assert_equal @user.id, journey.life_area.user_id
    assert_equal 1, journey.focus_position
    assert_equal "active", older.reload.status
    assert_nil older.focus_position
    assert_equal older_flags, older.setup_flags
    assert_equal completed_at.to_i, @user.reload.onboarding_completed_at.to_i
    assert_not_equal "true", journey.setup_flag(Onboarding::Bootstrap::BOOTSTRAP_FLAG)
    assert_equal "done", journey.setup_flag(Onboarding::Bootstrap::FIRST_CAMP_REVEAL_FLAG)

    goal = @user.strategy_goals.for_kind("goal").roots.find_by!(life_journey_id: journey.id)
    assert_equal "Weekly family dinner", goal.title
    plan = goal.children.find { |c| c.plan? && !c.holding? }
    assert plan
    camps = plan.children.select(&:project?).sort_by { |c| [ c.position.to_i, c.id ] }
    assert_equal [ "Pick a night", "Cook together" ], camps.map(&:title)

    get life_journey_path(journey)
    assert_response :success
    assert_select ".lp-rpg.is-v4-phone"
    assert_select ".lp-rpg-scenic", count: 0
  end

  test "empty name stays on step one and creates nothing" do
    assert_no_difference -> { @user.life_journeys.count } do
      post life_journeys_path(step: "goal"), params: {
        ring: "family_love",
        onboarding: { goal: "   " }
      }
    end

    assert_response :unprocessable_entity
    assert_select "#new_goal_name_error", text: I18n.t("v2_onboarding.need_goal")
    assert_select "input[type=radio][name=ring][value=family_love][checked]"
    assert_nil session[LifeJourneysController::NEW_GOAL_SESSION_KEY]
  end

  test "create with unknown ring returns 422 and creates nothing" do
    assert_no_difference -> { @user.life_journeys.count } do
      post life_journeys_path(step: "goal"), params: {
        ring: "spaceships",
        onboarding: { goal: "Nope" }
      }
    end

    assert_response :unprocessable_entity
    assert_match I18n.t("my_world.rings.unknown"), response.body
  end

  test "create never uses another users life area" do
    other = users(:two)
    other.update!(planning_version: 2, onboarding_completed_at: Time.current)
    LifeAreas::Select.call(user: other, keys: %w[relationships])
    foreign = other.life_areas.v2_selected.find_by!(key: "relationships")

    post life_journeys_path(step: "goal"), params: {
      ring: "family_love",
      onboarding: { goal: "My goal" }
    }
    assert_redirected_to new_life_journey_path(step: "camps")

    post life_journeys_path(step: "camps"), params: {
      ring: "family_love",
      life_area_id: foreign.id,
      onboarding: { camp_titles: [ "First camp" ] }
    }

    journey = @user.life_journeys.order(:id).last
    assert_redirected_to life_journey_path(journey)
    assert_equal @user.id, journey.user_id
    assert_equal @user.id, journey.life_area.user_id
    assert_not_equal foreign.id, journey.life_area_id
  end

  test "another user cannot use this users new goal draft" do
    post life_journeys_path(step: "goal"), params: {
      ring: "family_love",
      onboarding: { goal: "Private mountain" }
    }
    assert_redirected_to new_life_journey_path(step: "camps")
    assert_equal "Private mountain", session[LifeJourneysController::NEW_GOAL_SESSION_KEY]["goal"]

    other = users(:two)
    other.update!(planning_version: 2, onboarding_completed_at: Time.current)
    allow_extra_climbs!(other)
    sign_in_as other

    get new_life_journey_path(step: "camps")
    assert_redirected_to new_life_journey_path
    assert_nil session[LifeJourneysController::NEW_GOAL_SESSION_KEY]

    follow_redirect!
    assert_response :success
    refute_match(/Private mountain/, response.body)
  end
end
