require "test_helper"

class MagicalLoopTest < ActiveSupport::TestCase
  test "v2 loop: select areas, journey, focus, mission, complete moves LP and gap" do
    user = User.create!(
      email_address: "loop@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      home_stat_count: 6
    )

    Onboarding::Run.call(
      user: user,
      area_keys: %w[career learning],
      title: "Senior Rails developer",
      ideal_scene: "I ship products people love as a senior Rails engineer.",
      current_reality: "I am learning Rails and building small apps.",
      closer_percent: 30
    )

    user.reload
    assert user.planning_v2?
    assert user.onboarding_completed?
    journey = user.primary_focused_journey
    assert journey
    assert_in_delta 70.0, journey.gap_percent.to_f, 0.01

    mission = user.missions.for_day(Date.current).primary.first
    assert mission
    assert mission.is_primary?

    points_before = user.life_points
    gap_before = journey.gap_percent.to_f

    Missions::Complete.call(user: user, mission: mission)
    user.reload
    journey.reload

    assert mission.reload.completed?
    assert_equal points_before + mission.lp_reward, user.life_points
    assert journey.gap_percent.to_f < gap_before
  end

  test "focus switch never deletes journey progress" do
    user = users(:one)
    LifeAreas::Select.call(user: user, keys: %w[career purpose])
    areas = user.life_areas.v2_selected
    j1 = Journeys::Create.call(
      user: user,
      life_area: areas.first,
      title: "Career journey",
      ideal_scene: "Ideal career",
      current_reality: "Present career",
      closer_percent: 20
    )
    j2 = Journeys::Create.call(
      user: user,
      life_area: areas.second,
      title: "Purpose journey",
      ideal_scene: "Ideal purpose",
      current_reality: "Present purpose",
      closer_percent: 40
    )

    Focus::SetJourneys.call(user: user, journey_ids: [ j1.id ])
    j1.update!(gap_percent: 55)
    Focus::SetJourneys.call(user: user, journey_ids: [ j2.id ])

    assert_nil j1.reload.focus_position
    assert_equal 1, j2.reload.focus_position
    assert_in_delta 55.0, j1.gap_percent.to_f, 0.01
    assert j1.ideal_scene.present?
  end

  test "v2 habit completion does not award LP" do
    user = users(:one)
    user.update!(planning_version: 2, total_points: 100)
    habit = habits(:one)
    before = user.total_points
    Completion.create!(user: user, habit: habit, completed_on: Date.current + 10)
    assert_equal before, user.reload.total_points
  end
end
