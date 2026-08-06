# frozen_string_literal: true

require "test_helper"

module Notifications
  class MorningNudgesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @previous_secret = ENV["CRON_SECRET"]
      ENV["CRON_SECRET"] = "test-cron-secret-value"
      @user = users(:one)
      @user.daily_todos.delete_all
      @user.notification_preference&.destroy
      @user.push_subscriptions.delete_all

      PushSubscription.create!(
        user: @user,
        endpoint: "https://fcm.googleapis.com/fcm/send/morning-ctrl",
        p256dh: "BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTsHJQDSiUC_nNAw0QQxmlYjXz12WA0NedmzVoY_o0U0K2pU",
        auth: "tBHItJI5svbpez7KI4CCXg"
      )
      @user.create_notification_preference!(time_zone: "Europe/Berlin")

      @original_payload_send = WebPush.method(:payload_send)
      WebPush.define_singleton_method(:payload_send) { |**_kwargs| true }
    end

    teardown do
      ENV["CRON_SECRET"] = @previous_secret
      WebPush.define_singleton_method(:payload_send, @original_payload_send)
    end

    test "rejects missing secret" do
      post notifications_morning_nudge_path, as: :json
      assert_response :unauthorized
    end

    test "rejects wrong secret" do
      post notifications_morning_nudge_path,
           headers: { "Authorization" => "Bearer wrong-secret" },
           as: :json
      assert_response :unauthorized
    end

    test "runs with valid bearer secret" do
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 8, 15, 0) do
        post notifications_morning_nudge_path,
             headers: { "Authorization" => "Bearer test-cron-secret-value" },
             as: :json
      end

      assert_response :success
      body = JSON.parse(response.body)
      assert body["ok"]
      assert_equal 1, body["sent"]
      assert_equal Date.new(2026, 8, 6), @user.notification_preference.reload.last_morning_nudge_sent_on
    end
  end
end
