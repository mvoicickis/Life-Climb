# frozen_string_literal: true

require "test_helper"

class JourneysStartNextGoalTest < ActiveSupport::TestCase
  setup do
    Goals::Current.clear_cache!
    @user = User.create!(
      name: "Summit",
      email_address: "start-next-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )
    @bootstrap = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "First mountain",
      camp_titles: [ "Camp A", "Camp B" ]
    )
    @old_journey = @bootstrap.journey
    finish_all_camps!(@bootstrap.plan)
  end

  teardown do
    Goals::Current.clear_cache!
  end

  test "creates new journey completes old and clears seed battle" do
    result = Journeys::StartNextGoal.call(
      user: @user,
      old_journey: @old_journey,
      goal_title: "Second mountain",
      camp_titles: [ "New camp" ]
    )

    @old_journey.reload
    assert_equal "completed", @old_journey.status

    new_journey = result.journey
    assert_equal "active", new_journey.status
    assert_not_equal @old_journey.id, new_journey.id
    assert_equal @old_journey.life_area_id, new_journey.life_area_id
    assert_equal "Second mountain", result.goal.title
    assert_equal 1, result.projects.size
    assert_nil result.first_battle
    assert_equal 0, result.projects.first.children.for_kind("day").count
    assert_equal "done", new_journey.setup_flag(Onboarding::Bootstrap::FIRST_CAMP_REVEAL_FLAG)
    assert_nil new_journey.setup_flag(Onboarding::Bootstrap::BOOTSTRAP_FLAG)

    pair = Goals::Current.call(user: @user.reload)
    assert_equal new_journey.id, pair.journey.id
    assert_equal "Second mountain", pair.goal.title
  end

  test "second call raises already completed" do
    Journeys::StartNextGoal.call(
      user: @user,
      old_journey: @old_journey,
      goal_title: "Second mountain",
      camp_titles: [ "New camp" ]
    )

    assert_raises(Journeys::StartNextGoal::AlreadyCompleted) do
      Journeys::StartNextGoal.call(
        user: @user,
        old_journey: @old_journey,
        goal_title: "Third mountain",
        camp_titles: [ "Another" ]
      )
    end

    assert_equal 2, @user.life_journeys.count
  end

  private

  def finish_all_camps!(plan)
    plan.children.for_kind("project").not_holding.find_each do |camp|
      camp.children.for_kind("day").find_each { |b| b.update!(completed_at: Time.current) }
      camp.complete!
    end
  end
end
