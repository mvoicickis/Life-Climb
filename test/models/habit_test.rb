# frozen_string_literal: true

require "test_helper"

class HabitTest < ActiveSupport::TestCase
  include ClimbTestHelper

  test "optional life_journey link must belong to the habit owner" do
    user = users(:one)
    journey = seed_climb!(user)
    other = seed_climb!(users(:two), area_key: "health", title: "Other", today_mission: "Walk")

    habit = user.habits.build(
      name: "Push-ups", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth",
      life_journey: journey
    )
    assert habit.valid?

    habit.life_journey = other
    assert_not habit.valid?
    assert_includes habit.errors[:life_journey_id], "is invalid"

    habit.life_journey = nil
    assert habit.valid?
  end
end
