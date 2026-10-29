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
  end

  test "new preselects ring from query and does not redirect without selected areas" do
    @user.life_areas.where(dream_id: nil).update_all(selected_at: nil)

    get new_life_journey_path(ring: "family_love")
    assert_response :success
    assert_select "input[type=radio][name=ring][value=family_love][checked]"
    assert_select "input[type=radio][name=ring][value=me]:not([checked])"
  end

  test "create with ring family_love builds relationships journey and focuses it" do
    older = seed_climb!(@user, area_key: "career", title: "Career climb", today_mission: "Ship one")
    assert_equal "active", older.status
    assert_equal 1, older.focus_position

    assert_difference -> { @user.life_journeys.count }, 1 do
      post life_journeys_path, params: {
        ring: "family_love",
        life_journey: {
          title: "Sleep by 11",
          ideal_scene: "In bed before eleven",
          current_reality: "Scrolling late",
          next_win: "One early night",
          closer_percent: 10,
          today_mission: "Set an alarm for 10:30"
        }
      }
    end

    assert_redirected_to dashboard_path
    journey = @user.life_journeys.order(:id).last
    assert_equal "relationships", journey.life_area.key
    assert_equal @user.id, journey.life_area.user_id
    assert_equal 1, journey.focus_position
    assert_equal "active", older.reload.status
    assert_nil older.focus_position
  end

  test "create with unknown ring returns 422 and creates nothing" do
    assert_no_difference -> { @user.life_journeys.count } do
      post life_journeys_path, params: {
        ring: "spaceships",
        life_journey: {
          title: "Nope",
          ideal_scene: "Ideal",
          current_reality: "Present",
          today_mission: "Do a thing"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match I18n.t("my_world.rings.unknown"), response.body
  end

  test "create never uses another users life area" do
    other = users(:two)
    other.update!(planning_version: 2)
    LifeAreas::Select.call(user: other, keys: %w[relationships])
    foreign = other.life_areas.v2_selected.find_by!(key: "relationships")

    post life_journeys_path, params: {
      ring: "family_love",
      life_area_id: foreign.id,
      life_journey: {
        title: "My goal",
        ideal_scene: "Ideal",
        current_reality: "Present",
        today_mission: "One step"
      }
    }

    assert_redirected_to dashboard_path
    journey = @user.life_journeys.order(:id).last
    assert_equal @user.id, journey.user_id
    assert_equal @user.id, journey.life_area.user_id
    assert_not_equal foreign.id, journey.life_area_id
  end
end
