# frozen_string_literal: true

require "test_helper"

class ClimbStreakTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.update!(climb_streak_days: 0, climb_streak_on: nil)
  end

  test "first touch starts a one-day climb" do
    result = Climb::Streak.touch!(user: @user)
    assert_equal 1, result.days
    assert result.changed
    assert_equal Date.current, @user.reload.climb_streak_on
  end

  test "same-day touch does not double count" do
    Climb::Streak.touch!(user: @user)
    result = Climb::Streak.touch!(user: @user)
    assert_equal 1, result.days
    assert_not result.changed
  end

  test "next-day touch increases streak" do
    @user.update!(climb_streak_days: 2, climb_streak_on: Date.current - 1)
    result = Climb::Streak.touch!(user: @user)
    assert_equal 3, result.days
  end

  test "missed day quietly resets" do
    @user.update!(climb_streak_days: 5, climb_streak_on: Date.current - 3)
    assert_equal 0, Climb::Streak.current(user: @user)
    result = Climb::Streak.touch!(user: @user)
    assert_equal 1, result.days
  end
end
