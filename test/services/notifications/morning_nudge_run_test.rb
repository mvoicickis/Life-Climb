# frozen_string_literal: true

require "test_helper"

module Notifications
  class MorningNudgeRunTest < ActiveSupport::TestCase
    FakeResponse = Struct.new(:body, :inspect)

    setup do
      @user = users(:one)
      @user.daily_todos.delete_all
      @user.notification_preference&.destroy
      @user.push_subscriptions.delete_all

      PushSubscription.create!(
        user: @user,
        endpoint: "https://fcm.googleapis.com/fcm/send/morning-nudge",
        p256dh: "BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTsHJQDSiUC_nNAw0QQxmlYjXz12WA0NedmzVoY_o0U0K2pU",
        auth: "tBHItJI5svbpez7KI4CCXg"
      )

      @pref = @user.create_notification_preference!(time_zone: "Europe/Berlin")
      @original_payload_send = WebPush.method(:payload_send)
      @send_calls = 0
      @last_payload = nil

      test_case = self
      WebPush.define_singleton_method(:payload_send) do |**kwargs|
        test_case.instance_variable_set(:@last_payload, JSON.parse(kwargs[:message]))
        test_case.instance_variable_set(
          :@send_calls,
          test_case.instance_variable_get(:@send_calls) + 1
        )
        true
      end
    end

    teardown do
      WebPush.define_singleton_method(:payload_send, @original_payload_send)
    end

    test "sends once at Berlin 08:00 and dedupes same local day" do
      pool = (0..5).map { |i| I18n.t("notifications.morning_nudge.#{i}", locale: :en) }

      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 8, 0, 0) do
        result = MorningNudgeRun.call
        assert_equal 1, result.sent
        assert_equal 1, @send_calls
        assert_equal "morning", @last_payload["kind"]
        assert @last_payload["body"].start_with?("☀️ ")
        assert_includes pool, @last_payload["body"].delete_prefix("☀️ ")
        assert_equal Date.new(2026, 8, 6), @pref.reload.last_morning_nudge_sent_on

        @send_calls = 0
        second = MorningNudgeRun.call
        assert_equal 0, second.sent
        assert_equal 0, @send_calls
      end
    end

    test "skips when user already has a Today battle" do
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 8, 0, 0) do
        seed_climb!(@user, today_mission: "Already planned")
        assert @user.daily_todos.for_day(Date.current).exists?

        result = MorningNudgeRun.call
        assert_equal 0, result.sent
        assert_equal 0, @send_calls
      end
    end

    test "skips outside local morning window" do
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 12, 0, 0) do
        result = MorningNudgeRun.call
        assert_equal 0, result.sent
        assert_equal 0, @send_calls
      end
    end

    test "skips blank time_zone" do
      @pref.update!(time_zone: nil)

      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 8, 0, 0) do
        result = MorningNudgeRun.call
        assert_equal 0, result.sent
        assert_equal 0, @send_calls
      end
    end

    test "skips vacation_paused" do
      @pref.update!(vacation_paused: true)

      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 8, 0, 0) do
        result = MorningNudgeRun.call
        assert_equal 0, result.sent
        assert_equal 0, @send_calls
      end
    end

    test "skips frequency off" do
      @pref.update!(frequency: "off")

      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 8, 0, 0) do
        result = MorningNudgeRun.call
        assert_equal 0, result.sent
        assert_equal 0, @send_calls
      end
    end
  end
end
