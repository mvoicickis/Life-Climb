# frozen_string_literal: true

require "test_helper"

class ClimbStreakTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.update!(
      climb_streak_days: 0,
      climb_streak_on: nil,
      climb_streak_freezes: 0,
      climb_streak_frozen_on: nil,
      best_day_ap: 0
    )
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

  test "missed day without freeze quietly resets on reconcile" do
    @user.update!(climb_streak_days: 5, climb_streak_on: Date.current - 3, climb_streak_freezes: 0)
    result = Climb::Streak.reconcile!(user: @user)
    assert result.reset
    assert_equal 0, result.days
    assert_equal 0, @user.reload.climb_streak_days
  end

  test "single missed day with freeze is protected silently" do
    @user.update!(climb_streak_days: 4, climb_streak_on: Date.current - 2, climb_streak_freezes: 1)
    result = Climb::Streak.reconcile!(user: @user)
    assert result.consumed_freeze
    assert_not result.reset
    assert_equal 4, result.days
    assert_equal 0, @user.reload.climb_streak_freezes
    assert_equal Date.current - 1, @user.climb_streak_on
    assert_equal Date.current - 1, @user.climb_streak_frozen_on
    assert_equal 4, Climb::Streak.current(user: @user)
  end

  test "earns a Base Camp freeze at seven days" do
    @user.update!(climb_streak_days: 6, climb_streak_on: Date.current - 1, climb_streak_freezes: 0)
    result = Climb::Streak.touch!(user: @user)
    assert_equal 7, result.days
    assert result.earned_freeze
    assert_equal 1, @user.reload.climb_streak_freezes
  end

  test "freeze bank caps at two" do
    @user.update!(climb_streak_days: 6, climb_streak_on: Date.current - 1, climb_streak_freezes: 2)
    result = Climb::Streak.touch!(user: @user)
    assert_equal 7, result.days
    assert_not result.earned_freeze
    assert_equal 2, @user.reload.climb_streak_freezes
  end

  test "reconcile survives missing freeze columns" do
    @user.update!(climb_streak_days: 4, climb_streak_on: Date.current - 2)
    @user.define_singleton_method(:has_attribute?) do |name|
      return false if %i[climb_streak_freezes climb_streak_frozen_on].include?(name.to_sym)

      User.instance_method(:has_attribute?).bind_call(self, name)
    end

    result = Climb::Streak.reconcile!(user: @user)
    assert result.reset
    assert_equal 0, @user.reload.climb_streak_days
  end
end
