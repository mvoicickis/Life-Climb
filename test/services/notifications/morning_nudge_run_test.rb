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

    test "sends battle copy when incomplete todo exists on local day" do
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 8, 0, 0) do
        seed_climb!(@user, today_mission: "Warm up")
        @user.daily_todos.delete_all
        @user.daily_todos.create!(
          title: "Write tests",
          aspect_key: "career",
          scheduled_on: Date.new(2026, 8, 6),
          position: 0,
          lp_reward: 10
        )

        result = MorningNudgeRun.call
        assert_equal 1, result.sent
        assert_equal 1, @send_calls
        assert_equal "morning", @last_payload["kind"]
        assert_equal "Today's battle", @last_payload["title"]
        assert_equal "Write tests. Win it today.", @last_payload["body"]
        assert_equal "/dashboard", @last_payload["url"]
        expected_badge = Today::BattleOpenCount.for(user: @user, on: Date.new(2026, 8, 6))
        assert_equal expected_badge, @last_payload["badge"]
        assert expected_badge.positive?
        assert_equal Date.new(2026, 8, 6), @pref.reload.last_morning_nudge_sent_on
      end
    end

    test "sends plan copy when nothing planned" do
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 8, 0, 0) do
        result = MorningNudgeRun.call
        assert_equal 1, result.sent
        assert_equal "Plan today", @last_payload["title"]
        assert_equal "Pick one battle for today.", @last_payload["body"]
        assert_equal 0, @last_payload["badge"]
      end
    end

    test "sends plan copy when every battle today is done" do
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 8, 0, 0) do
        todo = @user.daily_todos.create!(
          title: "Already won",
          aspect_key: "career",
          scheduled_on: Date.new(2026, 8, 6),
          position: 0,
          lp_reward: 10
        )
        todo.update!(completed_at: Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 7, 0, 0))

        result = MorningNudgeRun.call
        assert_equal 1, result.sent
        assert_equal "Plan today", @last_payload["title"]
        assert_equal "Pick one battle for today.", @last_payload["body"]
        assert_equal 0, @last_payload["badge"]
      end
    end

    test "still sends when incomplete battle exists" do
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 8, 0, 0) do
        seed_climb!(@user, today_mission: "Already planned")
        assert @user.daily_todos.for_day(Date.current).incomplete.exists?

        result = MorningNudgeRun.call
        assert_equal 1, result.sent
        assert_equal 1, @send_calls
        assert_match(/Win it today/, @last_payload["body"])
      end
    end

    test "dedupes same local day across morning window" do
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 8, 0, 0) do
        result = MorningNudgeRun.call
        assert_equal 1, result.sent
        assert_equal Date.new(2026, 8, 6), @pref.reload.last_morning_nudge_sent_on
      end

      @send_calls = 0
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 10, 0, 0) do
        second = MorningNudgeRun.call
        assert_equal 0, second.sent
        assert_equal 0, @send_calls
      end
    end

    test "uses local date across UTC boundary for copy" do
      # 01:00 Berlin on Aug 7 is still Aug 6 23:00 UTC.
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 7, 8, 0, 0) do
        @user.daily_todos.create!(
          title: "Berlin day battle",
          aspect_key: "career",
          scheduled_on: Date.new(2026, 8, 7),
          position: 0,
          lp_reward: 10
        )

        result = MorningNudgeRun.call
        assert_equal 1, result.sent
        assert_equal "Berlin day battle. Win it today.", @last_payload["body"]
        assert_equal Date.new(2026, 8, 7), @pref.reload.last_morning_nudge_sent_on
      end
    end

    test "does not stamp sent_on when WebPush fails" do
      WebPush.define_singleton_method(:payload_send) do |**_kwargs|
        raise StandardError, "push failed"
      end

      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 8, 0, 0) do
        result = MorningNudgeRun.call
        assert_equal 0, result.sent
        assert_nil @pref.reload.last_morning_nudge_sent_on
      end

      WebPush.define_singleton_method(:payload_send) do |**kwargs|
        @last_payload = JSON.parse(kwargs[:message])
        true
      end

      # Restore working stub for retry assertion
      test_case = self
      WebPush.define_singleton_method(:payload_send) do |**kwargs|
        test_case.instance_variable_set(:@last_payload, JSON.parse(kwargs[:message]))
        test_case.instance_variable_set(
          :@send_calls,
          test_case.instance_variable_get(:@send_calls) + 1
        )
        true
      end

      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 10, 0, 0) do
        result = MorningNudgeRun.call
        assert_equal 1, result.sent
        assert_equal Date.new(2026, 8, 6), @pref.reload.last_morning_nudge_sent_on
      end
    end

    test "skips outside local morning window" do
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 12, 0, 0) do
        result = MorningNudgeRun.call
        assert_equal 0, result.sent
        assert_equal 0, @send_calls
      end
    end

    test "sends at local hour 11" do
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 11, 0, 0) do
        result = MorningNudgeRun.call
        assert_equal 1, result.sent
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
