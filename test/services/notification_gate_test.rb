# frozen_string_literal: true

require "test_helper"

class NotificationGateTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "allows when no preference record exists" do
    assert_nil @user.notification_preference
    result = NotificationGate.allow?(user: @user, kind: "test")
    assert result.allowed?
    assert_nil result.reason
  end

  test "skips when vacation_paused" do
    @user.create_notification_preference!(vacation_paused: true)
    result = NotificationGate.allow?(user: @user, kind: "test")
    refute result.allowed?
    assert_equal :vacation, result.reason
  end

  test "skips when vacation_until is today or future" do
    @user.create_notification_preference!(vacation_until: Date.current)
    result = NotificationGate.allow?(user: @user, kind: "test")
    refute result.allowed?
    assert_equal :vacation, result.reason
  end

  test "skips when frequency is off" do
    @user.create_notification_preference!(frequency: "off")
    result = NotificationGate.allow?(user: @user, kind: "test")
    refute result.allowed?
    assert_equal :frequency_off, result.reason
  end

  test "allows sometimes frequency with test kind" do
    @user.create_notification_preference!(frequency: "sometimes")
    result = NotificationGate.allow?(user: @user, kind: "test")
    assert result.allowed?
  end

  test "skips win kind when win notifications disabled" do
    @user.create_notification_preference!(win_notifications_enabled: false)
    result = NotificationGate.allow?(user: @user, kind: "win")
    refute result.allowed?
    assert_equal :trigger_disabled, result.reason
  end

  test "allows win kind when win notifications enabled" do
    @user.create_notification_preference!(win_notifications_enabled: true)
    result = NotificationGate.allow?(user: @user, kind: "win")
    assert result.allowed?
  end

  test "skips stuck kind when stuck notifications disabled" do
    @user.create_notification_preference!(stuck_notifications_enabled: false)
    result = NotificationGate.allow?(user: @user, kind: "stuck")
    refute result.allowed?
    assert_equal :trigger_disabled, result.reason
  end

  test "test kind still allowed when win and stuck disabled" do
    @user.create_notification_preference!(
      win_notifications_enabled: false,
      stuck_notifications_enabled: false
    )
    result = NotificationGate.allow?(user: @user, kind: "test")
    assert result.allowed?
  end

  test "skips during quiet hours with stored time_zone" do
    @user.create_notification_preference!(
      time_zone: "Europe/Berlin",
      quiet_hours_start: 22,
      quiet_hours_end: 7
    )

    travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 23, 0, 0) do
      result = NotificationGate.allow?(user: @user, kind: "test")
      refute result.allowed?
      assert_equal :quiet_hours, result.reason
    end
  end

  test "allows when quiet hours set but time_zone blank" do
    @user.create_notification_preference!(
      time_zone: nil,
      quiet_hours_start: 0,
      quiet_hours_end: 23
    )

    result = NotificationGate.allow?(user: @user, kind: "test")
    assert result.allowed?
  end

  test "allows outside quiet hours window" do
    @user.create_notification_preference!(
      time_zone: "Europe/Berlin",
      quiet_hours_start: 22,
      quiet_hours_end: 7
    )

    travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 12, 0, 0) do
      result = NotificationGate.allow?(user: @user, kind: "test")
      assert result.allowed?
    end
  end

  test "same-day quiet hours window uses half-open end" do
    @user.create_notification_preference!(
      time_zone: "UTC",
      quiet_hours_start: 9,
      quiet_hours_end: 17
    )

    travel_to Time.utc(2026, 8, 6, 9, 0, 0) do
      refute NotificationGate.allow?(user: @user, kind: "test").allowed?
    end

    travel_to Time.utc(2026, 8, 6, 17, 0, 0) do
      assert NotificationGate.allow?(user: @user, kind: "test").allowed?
    end
  end
end
