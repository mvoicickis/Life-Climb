# frozen_string_literal: true

require "test_helper"

class NotificationPreferenceTest < ActiveSupport::TestCase
  test "defaults on create" do
    pref = users(:one).create_notification_preference!

    assert_equal "sometimes", pref.frequency
    assert_equal "normal", pref.intensity
    assert pref.win_notifications_enabled?
    assert pref.stuck_notifications_enabled?
    refute pref.vacation_paused?
    assert_nil pref.quiet_hours_start
    assert_nil pref.quiet_hours_end
    assert_nil pref.time_zone
    assert_nil pref.vacation_until
  end

  test "rejects invalid frequency and intensity" do
    pref = users(:one).build_notification_preference(frequency: "always", intensity: "loud")
    assert_not pref.valid?
    assert_includes pref.errors[:frequency], "is not included in the list"
    assert_includes pref.errors[:intensity], "is not included in the list"
  end

  test "quiet hours must be 0..23 when present" do
    pref = users(:one).build_notification_preference(quiet_hours_start: 24, quiet_hours_end: -1)
    assert_not pref.valid?
    assert pref.errors[:quiet_hours_start].any?
    assert pref.errors[:quiet_hours_end].any?
  end

  test "time_zone must be a valid IANA identifier when present" do
    pref = users(:one).build_notification_preference(time_zone: "Not/AZone")
    assert_not pref.valid?
    assert pref.errors[:time_zone].any?

    pref.time_zone = "Europe/Berlin"
    assert pref.valid?
  end

  test "vacation_active? for pause flag and future until date" do
    pref = users(:one).build_notification_preference
    refute pref.vacation_active?

    pref.vacation_paused = true
    assert pref.vacation_active?

    pref.vacation_paused = false
    pref.vacation_until = Date.current
    assert pref.vacation_active?

    pref.vacation_until = Date.yesterday
    refute pref.vacation_active?
  end

  test "snoozed? is true only while snoozed_until is in the future" do
    pref = users(:one).build_notification_preference
    refute pref.snoozed?

    pref.snoozed_until = 1.hour.from_now
    assert pref.snoozed?

    pref.snoozed_until = 1.minute.ago
    refute pref.snoozed?
  end

  test "notification_preference! creates once" do
    user = users(:two)
    assert_nil user.notification_preference

    first = user.notification_preference!
    second = user.notification_preference!

    assert_equal first.id, second.id
    assert_equal 1, NotificationPreference.where(user: user).count
  end
end
