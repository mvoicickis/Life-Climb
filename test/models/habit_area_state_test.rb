# frozen_string_literal: true

require "test_helper"

class HabitAreaStateTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @habit = habits(:one)
    @area = @user.areas.create!(name: "Finance")
  end

  test "unfiled habit clears state and needs no state" do
    @habit.update!(area: @area, state: "attention", state_label_attention: "Slipping")
    assert @habit.attention?

    @habit.update!(area: nil)
    assert_nil @habit.state
    assert_not @habit.filed?
    assert_nil @habit.tracker_state_label
  end

  test "tracker state labels fall back and accept custom words" do
    @habit.update!(area: @area, state: "good")
    assert_equal "On track", @habit.tracker_state_label

    @habit.update!(state: "attention")
    assert_equal "Needs attention", @habit.tracker_state_label

    @habit.update!(state_label_good: "Growing", state_label_attention: "Slipping", state: "good")
    assert_equal "Growing", @habit.tracker_state_label
  end

  test "rejects area from another user" do
    other = users(:two).areas.create!(name: "Other")
    @habit.area = other
    assert_not @habit.valid?
    assert @habit.errors[:area_id].any?
  end

  test "sparkline returns daily amounts" do
    @habit.update!(unit: "pages", stat_type: "growth")
    @user.daily_logs.create!(habit: @habit, logged_on: Date.current, amount: 12)
    series = @habit.sparkline_amounts(days: 3)
    assert_equal 3, series.size
    assert_equal 12.0, series.last
  end
end
