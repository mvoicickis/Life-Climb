# frozen_string_literal: true

require "test_helper"

class HabitTest < ActiveSupport::TestCase
  include ClimbTestHelper

  test "optional life_journey link must belong to the habit owner" do
    user = users(:one)
    journey = seed_climb!(user)
    other = seed_climb!(users(:two), area_key: "self", title: "Other", today_mission: "Walk")

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

  test "identity_label is optional and blank strips to nil" do
    user = users(:one)
    habit = user.habits.build(
      name: "Read", unit: "pages", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth",
      identity_label: "  I am a reader  "
    )
    assert habit.valid?
    habit.save!
    assert_equal "I am a reader", habit.identity_label

    habit.identity_label = "   "
    assert habit.valid?
    habit.save!
    assert_nil habit.identity_label
  end

  test "quantity input is whole-number for count units and decimal for money distance hours" do
    user = users(:one)

    pages = user.habits.build(name: "Read", unit: "pages", points: 5, frequency: "daily", active: true, show_on_home: true)
    assert_equal 1, pages.quantity_input_step
    assert_equal "numeric", pages.quantity_inputmode
    assert_not pages.decimal_quantity_unit?

    steps = user.habits.build(name: "Walk", unit: "steps", points: 5, frequency: "daily", active: true, show_on_home: true)
    assert_equal 1, steps.quantity_input_step
    assert_equal "numeric", steps.quantity_inputmode

    messages = user.habits.build(name: "Outreach", unit: "messages", points: 5, frequency: "daily", active: true, show_on_home: true)
    assert_equal 1, messages.quantity_input_step
    assert_equal "numeric", messages.quantity_inputmode

    dms = user.habits.build(name: "DM", unit: "dms", points: 5, frequency: "daily", active: true, show_on_home: true)
    assert_equal 1, dms.quantity_input_step

    money = user.habits.build(name: "Save", unit: "money", points: 5, frequency: "daily", active: true, show_on_home: true)
    assert_equal :any, money.quantity_input_step
    assert_equal "decimal", money.quantity_inputmode
    assert money.decimal_quantity_unit?

    km = user.habits.build(name: "Run", unit: "km", points: 5, frequency: "daily", active: true, show_on_home: true)
    assert_equal :any, km.quantity_input_step
    assert_equal "decimal", km.quantity_inputmode

    hours = user.habits.build(name: "Sleep", unit: "hours", points: 5, frequency: "daily", active: true, show_on_home: true)
    assert_equal :any, hours.quantity_input_step
    assert_equal "decimal", hours.quantity_inputmode

    km_run = user.habits.build(name: "Jog", unit: "km run", points: 5, frequency: "daily", active: true, show_on_home: true)
    assert_equal :any, km_run.quantity_input_step
  end
end
