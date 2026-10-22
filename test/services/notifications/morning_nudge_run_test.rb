# frozen_string_literal: true

require "test_helper"

module Notifications
  class MorningNudgeRunTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

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
      clear_enqueued_jobs
    end

    def run_nudge_and_deliver
      result = nil
      assert_enqueued_jobs 1, only: SendWebPushJob do
        result = MorningNudgeRun.call
      end
      perform_enqueued_jobs
      result
    end

    test "sends battle body from strategy when ad-hoc todo exists on local day" do
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 8, 0, 0) do
        seed_climb!(@user, title: "Get my driving license", today_mission: "Warm up")
        @user.daily_todos.delete_all
        @user.daily_todos.create!(
          title: "Write tests",
          aspect_key: "career",
          scheduled_on: Date.new(2026, 8, 6),
          position: 0,
          lp_reward: 10
        )

        result = run_nudge_and_deliver
        assert_equal 1, result.sent
        assert_equal 1, @send_calls
        assert_equal "morning", @last_payload["kind"]
        assert_equal "Get my driving license", @last_payload["title"]
        assert_equal "Today: Warm up", @last_payload["body"]
        assert_equal "/dashboard", @last_payload["url"]
        assert_equal "daily-nudge", @last_payload["tag"]
        assert_equal "https://lifeclimb.app/images/push_mountain.webp", @last_payload["image"]
        expected_badge = Today::BattleOpenCount.for(user: @user, on: Date.new(2026, 8, 6))
        assert_equal expected_badge, @last_payload["badge"]
        assert expected_badge.positive?
        assert_equal Date.new(2026, 8, 6), @pref.reload.last_morning_nudge_sent_on
      end
    end

    test "sends plan title when nothing planned" do
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 8, 0, 0) do
        result = run_nudge_and_deliver
        assert_equal 1, result.sent
        assert_equal "Plan today", @last_payload["title"]
        assert_equal "Big goals fall to small steps. Take one.", @last_payload["body"]
        assert_equal "daily-nudge", @last_payload["tag"]
        assert_equal 0, @last_payload["badge"]
      end
    end

    test "still sends weekday body when every battle today is done" do
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 8, 0, 0) do
        seed_climb!(@user, title: "Get my driving license")
        won_at = Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 7, 0, 0)
        @user.daily_todos.for_day(Date.new(2026, 8, 6)).find_each do |todo|
          todo.update!(completed_at: won_at)
        end
        @user.strategy_goals.where(horizon: "day").find_each do |battle|
          battle.update!(completed_at: won_at) unless battle.repeat_recurring?
        end
        journey = @user.reload.primary_focused_journey
        journey.missions.for_day(Date.new(2026, 8, 6)).primary.find_each do |mission|
          mission.update!(status: "complete", completed_at: Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 7, 0, 0))
        end

        result = run_nudge_and_deliver
        assert_equal 1, result.sent
        assert_equal "Get my driving license", @last_payload["title"]
        assert_equal "Big goals fall to small steps. Take one.", @last_payload["body"]
        assert_equal 0, @last_payload["badge"]
      end
    end

    test "still sends when incomplete battle exists" do
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 8, 0, 0) do
        seed_climb!(@user, today_mission: "Already planned")
        assert @user.daily_todos.for_day(Date.current).incomplete.exists?

        result = run_nudge_and_deliver
        assert_equal 1, result.sent
        assert_equal 1, @send_calls
        assert_equal "Today: Already planned", @last_payload["body"]
      end
    end

    test "dedupes same local day across morning window" do
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 8, 0, 0) do
        result = run_nudge_and_deliver
        assert_equal 1, result.sent
        assert_equal Date.new(2026, 8, 6), @pref.reload.last_morning_nudge_sent_on
      end

      @send_calls = 0
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 10, 0, 0) do
        assert_no_enqueued_jobs only: SendWebPushJob do
          second = MorningNudgeRun.call
          assert_equal 0, second.sent
        end
        assert_equal 0, @send_calls
      end
    end

    test "uses local date across UTC boundary for copy" do
      # 01:00 Berlin on Aug 7 is still Aug 6 23:00 UTC.
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 7, 8, 0, 0) do
        seed_climb!(@user, title: "Get my driving license")
        @user.strategy_goals.where(horizon: "day").find_each do |battle|
          battle.update!(scheduled_on: Date.new(2026, 12, 1))
        end
        @user.daily_todos.delete_all
        @user.daily_todos.create!(
          title: "Berlin day battle",
          aspect_key: "career",
          scheduled_on: Date.new(2026, 8, 7),
          position: 0,
          lp_reward: 10
        )

        result = run_nudge_and_deliver
        assert_equal 1, result.sent
        assert_equal "This is why you started. Keep going.", @last_payload["body"]
        assert_equal Date.new(2026, 8, 7), @pref.reload.last_morning_nudge_sent_on
      end
    end

    test "claims send date on enqueue so a second cron pass does not double-send" do
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 8, 0, 0) do
        assert_enqueued_jobs 1, only: SendWebPushJob do
          result = MorningNudgeRun.call
          assert_equal 1, result.sent
        end
        assert_equal Date.new(2026, 8, 6), @pref.reload.last_morning_nudge_sent_on

        WebPush.define_singleton_method(:payload_send) do |**_kwargs|
          raise StandardError, "push failed"
        end
        perform_enqueued_jobs

        assert_no_enqueued_jobs only: SendWebPushJob do
          second = MorningNudgeRun.call
          assert_equal 0, second.sent
        end
      end
    end

    test "skips outside local morning window without reconcile" do
      @user.update!(day_shield_on: Date.new(2020, 1, 1), day_shields_available: 0)

      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 12, 0, 0) do
        assert_no_enqueued_jobs only: SendWebPushJob do
          result = MorningNudgeRun.call
          assert_equal 0, result.sent
        end
        assert_equal 0, @send_calls
        assert_equal Date.new(2020, 1, 1), @user.reload.day_shield_on
      end
    end

    test "sends at local hour 11" do
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 11, 0, 0) do
        result = run_nudge_and_deliver
        assert_equal 1, result.sent
      end
    end

    test "skips blank time_zone" do
      @pref.update!(time_zone: nil)

      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 8, 0, 0) do
        assert_no_enqueued_jobs only: SendWebPushJob do
          result = MorningNudgeRun.call
          assert_equal 0, result.sent
        end
        assert_equal 0, @send_calls
      end
    end

    test "skips vacation_paused" do
      @pref.update!(vacation_paused: true)

      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 8, 0, 0) do
        assert_no_enqueued_jobs only: SendWebPushJob do
          result = MorningNudgeRun.call
          assert_equal 0, result.sent
        end
        assert_equal 0, @send_calls
      end
    end

    test "skips frequency off" do
      @pref.update!(frequency: "off")

      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 8, 0, 0) do
        assert_no_enqueued_jobs only: SendWebPushJob do
          result = MorningNudgeRun.call
          assert_equal 0, result.sent
        end
        assert_equal 0, @send_calls
      end
    end
  end
end
