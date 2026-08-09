# frozen_string_literal: true

require "test_helper"

class HabitQuantityCheckinTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "infer_quantity_checkin? matches the legacy heuristic" do
    assert Habit.infer_quantity_checkin?(stat_type: "standard", goal: nil, unit: "times")
    assert Habit.infer_quantity_checkin?(stat_type: "growth", goal: 10, unit: "times")
    assert Habit.infer_quantity_checkin?(stat_type: "growth", goal: nil, unit: "pages")
    assert_not Habit.infer_quantity_checkin?(stat_type: "growth", goal: nil, unit: "times")
  end

  test "explicit quantity_checkin true with unit times is quantity not binary" do
    habit = @user.habits.create!(
      name: "Push-Ups",
      unit: "times",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "growth",
      quantity_checkin: true
    )

    assert habit.quantity_checkin?
    assert_not habit.binary_checkin?
  end

  test "create without explicit flag infers from unit" do
    pages = @user.habits.create!(
      name: "Pages read",
      unit: "pages",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "growth"
    )
    meditate = @user.habits.create!(
      name: "Meditate",
      unit: "times",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "growth"
    )

    assert pages.quantity_checkin?
    assert meditate.binary_checkin?
  end

  test "migration backfill and corrections for push-ups and logged habits" do
    false_negative = Habit.new(
      user: @user,
      name: "Push ups club",
      unit: "times",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "growth",
      quantity_checkin: false
    )
    false_negative.save!(validate: false)

    logged = Habit.new(
      user: @user,
      name: "Mystery reps",
      unit: "times",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "growth",
      quantity_checkin: false
    )
    logged.save!(validate: false)
    logged.daily_logs.create!(user: @user, logged_on: Date.yesterday, amount: 12)

    glasses = Habit.new(
      user: @user,
      name: "Water",
      unit: "glasses",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "growth",
      quantity_checkin: false
    )
    glasses.save!(validate: false)

    binary = Habit.new(
      user: @user,
      name: "Pray",
      unit: "times",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "growth",
      quantity_checkin: false
    )
    binary.save!(validate: false)

    # Re-apply the migration correction SQL against these rows.
    Habit.connection.execute(<<~SQL.squish)
      UPDATE habits
      SET quantity_checkin = CASE
        WHEN stat_type = 'standard' THEN TRUE
        WHEN goal IS NOT NULL THEN TRUE
        WHEN lower(unit) != 'times' THEN TRUE
        ELSE FALSE
      END
      WHERE id IN (#{[ false_negative.id, logged.id, glasses.id, binary.id ].join(',')})
    SQL
    Habit.connection.execute(<<~SQL.squish)
      UPDATE habits
      SET quantity_checkin = TRUE
      WHERE quantity_checkin = FALSE
        AND lower(name) LIKE '%push%up%'
        AND id IN (#{[ false_negative.id, logged.id, glasses.id, binary.id ].join(',')})
    SQL
    Habit.connection.execute(<<~SQL.squish)
      UPDATE habits
      SET quantity_checkin = TRUE
      WHERE quantity_checkin = FALSE
        AND id IN (SELECT DISTINCT habit_id FROM daily_logs WHERE habit_id IS NOT NULL)
        AND id IN (#{[ false_negative.id, logged.id, glasses.id, binary.id ].join(',')})
    SQL

    assert false_negative.reload.quantity_checkin?
    assert logged.reload.quantity_checkin?
    assert glasses.reload.quantity_checkin?
    assert_not binary.reload.quantity_checkin?
  end
end
