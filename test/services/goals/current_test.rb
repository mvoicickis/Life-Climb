# frozen_string_literal: true

require "test_helper"

class Goals::CurrentTest < ActiveSupport::TestCase
  setup do
    Goals::Current.clear_cache!
    @user = users(:one)
    @user.update!(character: "fox", planning_version: 2)
    @result = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Ship the climb",
      camp_titles: [ "First camp", "Second camp" ]
    )
    @journey = @result.journey
    @goal = @result.goal
  end

  teardown do
    Goals::Current.clear_cache!
  end

  test "resolves focused journey and journey-scoped root goal" do
    pair = Goals::Current.call(user: @user.reload)

    assert_equal @journey.id, pair.journey.id
    assert_equal @goal.id, pair.goal.id
  end

  test "memoizes per user within the request" do
    queries = 0
    callback = lambda do |_name, _start, _finish, _id, payload|
      next if payload[:cached]
      next unless payload[:sql].to_s.include?("life_journeys")

      queries += 1
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      2.times { Goals::Current.call(user: @user.reload) }
    end

    assert_equal 1, queries
  end

  test "legacy nil life_journey_id root is used when journey has no scoped root" do
    @goal.update_column(:life_journey_id, nil)
    Goals::Current.clear_cache!(user: @user)

    pair = Goals::Current.call(user: @user.reload)
    assert_equal @goal.id, pair.goal.id
  end

  test "journey-scoped root wins over legacy nil in same area" do
    area = @journey.life_area
    journey_b = Journeys::Create.call(
      user: @user,
      life_area: area,
      title: "Next climb",
      ideal_scene: "Done",
      current_reality: "Starting",
      closer_percent: 10
    )
    goal_b = @user.strategy_goals.create!(
      life_area: area,
      life_journey: journey_b,
      horizon: "goal",
      title: "Next climb",
      position: 1,
      due_on: Strategy::YearCycle.default_goal_due
    )
    @goal.update_column(:life_journey_id, nil)
    Focus::SetJourneys.call(user: @user, journey_ids: [ journey_b.id ])
    Goals::Current.clear_cache!(user: @user)

    pair = Goals::Current.call(user: @user.reload)
    assert_equal journey_b.id, pair.journey.id
    assert_equal goal_b.id, pair.goal.id
  end

  test "clear_cache after complete returns next journey goal in same request" do
    area = @journey.life_area
    journey_b, goal_b = create_second_climb!(area:, goal_title: "Run a half marathon")
    Focus::SetJourneys.call(user: @user, journey_ids: [ @journey.id ])
    Goals::Current.clear_cache!(user: @user)

    before = Goals::Current.call(user: @user.reload)
    assert_equal @goal.id, before.goal.id

    Journeys::Complete.call(user: @user, journey: @journey)
    Focus::SetJourneys.call(user: @user, journey_ids: [ journey_b.id ])

    after = Goals::Current.call(user: @user.reload)
    assert_equal journey_b.id, after.journey.id
    assert_equal goal_b.id, after.goal.id
    assert_not_equal before.goal.id, after.goal.id
  end

  test "goal_for honors explicit goal_id" do
    area = @journey.life_area
    _journey_b, goal_b = create_second_climb!(area:, goal_title: "Other goal")

    found = Goals::Current.goal_for(user: @user.reload, journey: @journey, goal_id: goal_b.id)
    assert_equal goal_b.id, found.id
  end

  private

  def create_second_climb!(area:, goal_title:)
    journey = Journeys::Create.call(
      user: @user,
      life_area: area,
      title: goal_title,
      ideal_scene: "Ideal",
      current_reality: "Now",
      closer_percent: 15
    )
    goal = @user.strategy_goals.create!(
      life_area: area,
      life_journey: journey,
      horizon: "goal",
      title: goal_title,
      position: 1,
      due_on: Strategy::YearCycle.default_goal_due
    )
    plan = goal.children.create!(
      user: @user,
      life_area: area,
      life_journey: journey,
      horizon: "plan",
      title: "Main path",
      position: 0
    )
    project = plan.children.create!(
      user: @user,
      life_area: area,
      life_journey: journey,
      horizon: "project",
      title: "Camp one",
      position: 0,
      stage: 0
    )
    project.children.create!(
      user: @user,
      life_area: area,
      life_journey: journey,
      horizon: "day",
      title: "Daily step",
      scheduled_on: Date.current,
      position: 0,
      repeat: "daily"
    )
    [ journey, goal ]
  end
end
