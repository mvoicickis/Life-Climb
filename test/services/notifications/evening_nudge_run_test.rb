# frozen_string_literal: true

require "test_helper"

module Notifications
  class EveningNudgeRunTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @user.daily_todos.delete_all
      @user.notification_preference&.destroy
      @user.push_subscriptions.delete_all

      PushSubscription.create!(
        user: @user,
        endpoint: "https://fcm.googleapis.com/fcm/send/evening-nudge",
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

    test "sends goal title and evening body in local window" do
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 20, 0, 0) do
        seed_climb!(@user, title: "Get my driving license", today_mission: "Warm up")

        result = EveningNudgeRun.call
        assert_equal 1, result.sent
        assert_equal 1, @send_calls
        assert_equal "evening", @last_payload["kind"]
        assert_equal "Get my driving license", @last_payload["title"]
        assert_equal "Today: Warm up", @last_payload["body"]
        assert_equal "/dashboard", @last_payload["url"]
        assert_equal "daily-nudge", @last_payload["tag"]
        assert_equal "https://lifeclimb.app/images/push_mountain.webp", @last_payload["image"]
        assert_equal [], @last_payload["actions"]
        assert_equal Date.new(2026, 8, 6), @pref.reload.last_evening_nudge_sent_on
      end
    end

    test "dedupes same local day across evening window" do
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 20, 0, 0) do
        assert_equal 1, EveningNudgeRun.call.sent
      end

      @send_calls = 0
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 21, 0, 0) do
        second = EveningNudgeRun.call
        assert_equal 0, second.sent
        assert_equal 0, @send_calls
      end
    end

    test "skips when daily battle won today" do
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 20, 0, 0) do
        seed_climb!(@user, today_mission: "Stretch daily")
        battle = @user.strategy_goals.find_by!(horizon: "day", title: "Stretch daily")
        battle.update!(repeat: "daily")
        Strategy::CascadeToDaily.call(
          user: @user,
          life_area: battle.life_area,
          from: Date.new(2026, 8, 6),
          to: Date.new(2026, 8, 6)
        )
        todo = @user.daily_todos.for_day(Date.new(2026, 8, 6)).find_by!(strategy_goal_id: battle.id)
        todo.update!(completed_at: Time.current)

        result = EveningNudgeRun.call
        assert_equal 0, result.sent
        assert_nil @pref.reload.last_evening_nudge_sent_on
      end
    end

    test "skips when one-shot battle won today" do
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 20, 0, 0) do
        seed_climb!(@user, today_mission: "Ship auth")
        battle = @user.strategy_goals.find_by!(horizon: "day", title: "Ship auth")
        battle.update!(completed_at: Time.current)

        result = EveningNudgeRun.call
        assert_equal 0, result.sent
      end
    end

    test "still sends when one-shot won yesterday" do
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 20, 0, 0) do
        seed_climb!(@user, today_mission: "Yesterday win")
        battle = @user.strategy_goals.find_by!(horizon: "day", title: "Yesterday win")
        battle.update!(completed_at: Time.find_zone!("Europe/Berlin").local(2026, 8, 5, 9, 0, 0))

        result = EveningNudgeRun.call
        assert_equal 1, result.sent
      end
    end

    test "basic done today without battle win still sends" do
      enable_habits!
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 20, 0, 0) do
        habit = @user.habits.create!(
          name: "Drink water",
          unit: "times",
          points: 10,
          frequency: "daily",
          active: true,
          show_on_home: true,
          quantity_checkin: false
        )
        habit.completions.create!(user: @user, completed_on: Date.new(2026, 8, 6), points_awarded: 10)

        result = EveningNudgeRun.call
        assert_equal 1, result.sent
      end
    end

    test "uses local date across UTC boundary" do
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 7, 20, 0, 0) do
        result = EveningNudgeRun.call
        assert_equal 1, result.sent
        assert_equal Date.new(2026, 8, 7), @pref.reload.last_evening_nudge_sent_on
      end
    end

    test "skips outside local evening window" do
      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 18, 0, 0) do
        result = EveningNudgeRun.call
        assert_equal 0, result.sent
        assert_equal 0, @send_calls
      end
    end

    test "skips blank time_zone" do
      @pref.update!(time_zone: nil)

      travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 20, 0, 0) do
        result = EveningNudgeRun.call
        assert_equal 0, result.sent
      end
    end
  end
end
