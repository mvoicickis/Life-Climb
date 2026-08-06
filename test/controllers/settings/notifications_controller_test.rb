# frozen_string_literal: true

require "test_helper"

module Settings
  class NotificationsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
    end

    test "show creates preference and renders form" do
      assert_nil @user.notification_preference

      get settings_notifications_path
      assert_response :success
      assert @user.reload.notification_preference.present?
      assert_select "h1", text: "Notifications"
      assert_select "form[action=?]", settings_notifications_path
      assert_select "select[name=?]", "notification_preference[frequency]"
      assert_select "select[name=?]", "notification_preference[intensity]"
      assert_select "input[name=?]", "notification_preference[vacation_until]"
      assert_select "input[name=?]", "notification_preference[vacation_paused]"
      assert_select "input[name=?]", "notification_preference[win_notifications_enabled]"
      assert_select "input[name=?]", "notification_preference[stuck_notifications_enabled]"
      assert_select "[data-controller=?]", "notification-timezone"
    end

    test "update saves all preference fields" do
      @user.notification_preference!

      patch settings_notifications_path, params: {
        notification_preference: {
          frequency: "rarely",
          intensity: "gentle",
          quiet_hours_start: 22,
          quiet_hours_end: 7,
          time_zone: "Europe/Riga",
          vacation_until: "2026-09-01",
          vacation_paused: "0",
          win_notifications_enabled: "0",
          stuck_notifications_enabled: "1"
        }
      }

      assert_redirected_to settings_notifications_path
      pref = @user.reload.notification_preference
      assert_equal "rarely", pref.frequency
      assert_equal "gentle", pref.intensity
      assert_equal 22, pref.quiet_hours_start
      assert_equal 7, pref.quiet_hours_end
      assert_equal "Europe/Riga", pref.time_zone
      assert_equal Date.new(2026, 9, 1), pref.vacation_until
      refute pref.vacation_paused?
      refute pref.win_notifications_enabled?
      assert pref.stuck_notifications_enabled?
    end

    test "json timezone-only patch updates time_zone" do
      pref = @user.notification_preference!
      assert_nil pref.time_zone

      patch settings_notifications_path(format: :json),
            params: { notification_preference: { time_zone: "America/New_York" } },
            as: :json

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal true, body["ok"]
      assert_equal "America/New_York", body["time_zone"]
      assert_equal "America/New_York", pref.reload.time_zone
    end

    test "unauthenticated redirect" do
      delete session_path
      get settings_notifications_path
      assert_redirected_to new_session_path
    end
  end
end
