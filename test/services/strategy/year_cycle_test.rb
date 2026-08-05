# frozen_string_literal: true

require "test_helper"

class Strategy::YearCycleTest < ActiveSupport::TestCase
  test "default_goal_due is one year from today" do
    assert_equal Date.new(2027, 7, 24), Strategy::YearCycle.default_goal_due(Date.new(2026, 7, 24))
    assert_equal Date.new(2027, 2, 28), Strategy::YearCycle.default_goal_due(Date.new(2026, 2, 28))
  end

  test "target_dec29 is this year before or on Dec 29" do
    assert_equal Date.new(2026, 12, 29), Strategy::YearCycle.target_dec29(Date.new(2026, 7, 24))
    assert_equal Date.new(2026, 12, 29), Strategy::YearCycle.target_dec29(Date.new(2026, 12, 29))
  end

  test "target_dec29 rolls to next year after Dec 29" do
    assert_equal Date.new(2027, 12, 29), Strategy::YearCycle.target_dec29(Date.new(2026, 12, 30))
  end

  test "remaining_month_slots from July through Dec 29" do
    slots = Strategy::YearCycle.remaining_month_slots(today: Date.new(2026, 7, 15), target: Date.new(2026, 12, 29))
    assert_equal 6, slots.size
    assert_equal Date.new(2026, 7, 31), slots.first[:due_on]
    assert_equal Date.new(2026, 12, 29), slots.last[:due_on]
  end

  test "dec29? helper" do
    assert Strategy::YearCycle.dec29?(Date.new(2026, 12, 29))
    assert_not Strategy::YearCycle.dec29?(Date.new(2026, 12, 31))
  end
end
