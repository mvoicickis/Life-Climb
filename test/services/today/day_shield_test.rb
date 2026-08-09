# frozen_string_literal: true

require "test_helper"

class Today::DayShieldTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.update!(day_shields_available: 0, day_shield_on: Date.current - 1)
  end

  test "reconcile resets to one shield for a new calendar day" do
    status = Today::DayShield.reconcile!(user: @user, date: Date.current)
    assert_equal 1, @user.reload.day_shields_available
    assert_equal Date.current, @user.day_shield_on
    assert status.available
  end

  test "available? is true after daily reset" do
    assert Today::DayShield.available?(user: @user, date: Date.current)
  end

  test "consume! spends the shield once and does not stack" do
    Today::DayShield.reconcile!(user: @user, date: Date.current)
    assert Today::DayShield.consume!(user: @user, date: Date.current)
    assert_equal 0, @user.reload.day_shields_available
    assert_not Today::DayShield.consume!(user: @user, date: Date.current)
    assert_equal 0, @user.reload.day_shields_available
  end

  test "same-day reconcile does not refill a spent shield" do
    Today::DayShield.reconcile!(user: @user, date: Date.current)
    Today::DayShield.consume!(user: @user, date: Date.current)
    Today::DayShield.reconcile!(user: @user, date: Date.current)
    assert_equal 0, @user.reload.day_shields_available
  end
end
