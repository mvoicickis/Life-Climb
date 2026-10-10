# frozen_string_literal: true

require "test_helper"

module Notifications
  class EnsureTimeZoneTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @user.notification_preference&.destroy
    end

    test "creates preference and sets zone when blank" do
      assert EnsureTimeZone.call(user: @user, zone: "Europe/Berlin")
      pref = @user.reload.notification_preference
      assert_equal "Europe/Berlin", pref.time_zone
    end

    test "does not overwrite existing zone" do
      @user.create_notification_preference!(time_zone: "America/New_York")

      refute EnsureTimeZone.call(user: @user, zone: "Europe/Berlin")
      assert_equal "America/New_York", @user.reload.notification_preference.time_zone
    end

    test "ignores invalid zone" do
      refute EnsureTimeZone.call(user: @user, zone: "Not/A/Zone")
      assert_nil @user.reload.notification_preference
    end

    test "ignores blank zone" do
      refute EnsureTimeZone.call(user: @user, zone: "")
      assert_nil @user.reload.notification_preference
    end
  end
end
