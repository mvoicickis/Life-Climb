require "test_helper"

class MagicalLoopTest < ActiveSupport::TestCase
  test "one-mountain loop: area, journey, mission, complete moves LP and gap" do
    user = User.create!(
      email_address: "loop@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      home_stat_count: 6
    )

    Onboarding::Run.call(
      user: user,
      area_key: "career",
      title: "Become a Senior Rails Developer",
      ideal_scene: "Working as a Rails developer building products I love.",
      current_reality: "Learning Rails and building personal projects.",
      next_win: "Finish Rails Fundamentals",
      today_mission: "Read 20 pages",
      closer_percent: 5
    )

    user.reload
    assert user.planning_v2?
    assert user.onboarding_completed?
    journey = user.primary_focused_journey
    assert journey
    assert_equal "career", journey.life_area.key
    assert_equal "Become a Senior Rails Developer", journey.title
    assert_equal "Finish Rails Fundamentals", journey.next_win
    assert_in_delta 95.0, journey.gap_percent.to_f, 0.01
    assert_in_delta 5.0, journey.closer_percent, 0.01

    mission = user.missions.for_day(Date.current).primary.first
    assert mission
    assert_equal "Read 20 pages", mission.title

    points_before = user.life_points
    gap_before = journey.gap_percent.to_f

    Missions::Complete.call(user: user, mission: mission)
    user.reload
    journey.reload

    assert mission.reload.completed?
    assert_equal points_before + mission.lp_reward, user.life_points
    assert journey.gap_percent.to_f < gap_before
  end

  test "journey create allows blank milestone" do
    user = users(:one)
    LifeAreas::Select.call(user: user, keys: %w[career])
    area = user.life_areas.v2_selected.first
    journey = Journeys::Create.call(
      user: user,
      life_area: area,
      title: "Career journey",
      ideal_scene: "Ideal career",
      current_reality: "Present career",
      next_win: nil,
      closer_percent: 5
    )
    assert_nil journey.next_win.presence
    assert_in_delta 95.0, journey.gap_percent.to_f, 0.01
  end

  test "completing a journey awards LP and clears focus" do
    user = users(:one)
    LifeAreas::Select.call(user: user, keys: %w[career])
    area = user.life_areas.v2_selected.first
    journey = Journeys::Create.call(
      user: user,
      life_area: area,
      title: "Career journey",
      ideal_scene: "Ideal career",
      current_reality: "Present career",
      next_win: "Land first interview",
      closer_percent: 20
    )
    Focus::SetJourneys.call(user: user, journey_ids: [ journey.id ])
    before = user.life_points

    Journeys::Complete.call(user: user, journey: journey)
    journey.reload
    user.reload

    assert_equal "completed", journey.status
    assert_nil journey.focus_position
    assert_equal before + Journeys::Complete::COMPLETION_LP, user.life_points
  end

  test "begin climb on a new area keeps prior areas and focuses the new journey" do
    user = users(:two)
    Onboarding::Run.call(
      user: user,
      area_key: "career",
      title: "First",
      ideal_scene: "Ideal A",
      current_reality: "Present A",
      next_win: "Next A",
      today_mission: "Do A today",
      closer_percent: 40
    )
    first = user.primary_focused_journey
    Journeys::Complete.call(user: user, journey: first)

    second = Journeys::BeginClimb.call(
      user: user,
      area_key: "purpose",
      title: "Purpose climb",
      ideal_scene: "Clear purpose",
      current_reality: "Searching",
      next_win: "Write purpose statement",
      today_mission: "Journal for 20 minutes",
      closer_percent: 25
    )

    assert_equal %w[career purpose].sort, user.life_areas.v2_selected.pluck(:key).sort
    assert_equal second.id, user.primary_focused_journey.id
    assert_equal "Write purpose statement", second.next_win
    assert_equal "Journal for 20 minutes", second.missions.for_day(Date.current).primary.first.title
    assert_nil first.reload.focus_position
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
