# frozen_string_literal: true

require "test_helper"

class LifeJourneyWithDestinationTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    allow_extra_climbs!(@user)
    @result = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "With spine",
      camp_titles: [ "Camp" ]
    )
    @journey = @result.journey
  end

  test "with_destination includes active climbs that have a root goal" do
    assert_includes @user.life_journeys.with_destination, @journey
  end

  test "with_destination excludes active climbs with no root goal" do
    @user.strategy_goals.for_kind("goal").roots.where(life_journey_id: @journey.id).destroy_all

    refute_includes @user.life_journeys.with_destination.reload, @journey
    assert_includes @user.life_journeys.active, @journey
  end

  test "with_destination excludes archived climbs even when a root goal remains" do
    @journey.update!(status: "archived")

    refute_includes @user.life_journeys.with_destination, @journey
  end
end