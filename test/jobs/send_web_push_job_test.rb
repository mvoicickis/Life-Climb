# frozen_string_literal: true

require "test_helper"

class SendWebPushJobTest < ActiveJob::TestCase
  FakeResponse = Struct.new(:body, :inspect)

  setup do
    @user = users(:one)
    @subscription = PushSubscription.create!(
      user: @user,
      endpoint: "https://fcm.googleapis.com/fcm/send/test-endpoint",
      p256dh: "BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTsHJQDSiUC_nNAw0QQxmlYjXz12WA0NedmzVoY_o0U0K2pU",
      auth: "tBHItJI5svbpez7KI4CCXg"
    )
    @original_payload_send = WebPush.method(:payload_send)
    @send_calls = 0
    @last_kwargs = nil

    test_case = self
    WebPush.define_singleton_method(:payload_send) do |**kwargs|
      test_case.instance_variable_set(:@last_kwargs, kwargs)
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

  test "calls WebPush for each subscription" do
    SendWebPushJob.perform_now(@user.id, { "title" => "Hi", "body" => "Test", "url" => "/dashboard" })

    assert_equal 1, @send_calls
    assert_equal @subscription.endpoint, @last_kwargs[:endpoint]
    assert_includes @last_kwargs[:message], "Hi"
  end

  test "destroys expired subscriptions" do
    WebPush.define_singleton_method(:payload_send) do |**_kwargs|
      raise WebPush::ExpiredSubscription.new(FakeResponse.new("gone", "#<Fake 410>"), "push.example")
    end

    assert_difference -> { PushSubscription.count }, -1 do
      SendWebPushJob.perform_now(@user.id, { "title" => "Hi" })
    end
  end

  test "no-ops when user is missing" do
    assert_nothing_raised do
      SendWebPushJob.perform_now(-1, { "title" => "Hi" })
    end
    assert_equal 0, @send_calls
  end

  test "does not send when vacation_paused" do
    @user.create_notification_preference!(vacation_paused: true)
    SendWebPushJob.perform_now(@user.id, { "title" => "Hi", "kind" => "test" })
    assert_equal 0, @send_calls
  end

  test "does not send when frequency is off" do
    @user.create_notification_preference!(frequency: "off")
    SendWebPushJob.perform_now(@user.id, { "title" => "Hi", "kind" => "test" })
    assert_equal 0, @send_calls
  end

  test "does not send win kind when win disabled" do
    @user.create_notification_preference!(win_notifications_enabled: false)
    SendWebPushJob.perform_now(@user.id, { "title" => "Win", "kind" => "win" })
    assert_equal 0, @send_calls
  end

  test "still sends test kind when win and stuck disabled" do
    @user.create_notification_preference!(
      win_notifications_enabled: false,
      stuck_notifications_enabled: false
    )
    SendWebPushJob.perform_now(@user.id, { "title" => "Test", "kind" => "test" })
    assert_equal 1, @send_calls
  end

  test "does not send during quiet hours" do
    @user.create_notification_preference!(
      time_zone: "UTC",
      quiet_hours_start: 22,
      quiet_hours_end: 7
    )

    travel_to Time.utc(2026, 8, 6, 23, 30, 0) do
      SendWebPushJob.perform_now(@user.id, { "title" => "Hi", "kind" => "test" })
    end
    assert_equal 0, @send_calls
  end

  test "sends when quiet hours configured without time_zone" do
    @user.create_notification_preference!(
      time_zone: nil,
      quiet_hours_start: 0,
      quiet_hours_end: 23
    )
    SendWebPushJob.perform_now(@user.id, { "title" => "Hi", "kind" => "test" })
    assert_equal 1, @send_calls
  end

  test "includes gentle intensity from preference in payload" do
    @user.create_notification_preference!(intensity: "gentle")
    SendWebPushJob.perform_now(@user.id, { "title" => "Hi", "kind" => "test" })

    payload = JSON.parse(@last_kwargs[:message])
    assert_equal "gentle", payload["intensity"]
  end

  test "defaults intensity to normal when no preference" do
    assert_nil @user.notification_preference
    SendWebPushJob.perform_now(@user.id, { "title" => "Hi", "kind" => "test" })

    payload = JSON.parse(@last_kwargs[:message])
    assert_equal "normal", payload["intensity"]
  end

  test "win kind replaces body from phrase bank for category" do
    @user.create_notification_preference!(intensity: "persistent")
    pool = Notifications::PhraseBank.phrases_for(kind: "win", category: "career", locale: :en)

    SendWebPushJob.perform_now(
      @user.id,
      { "title" => "Win", "body" => "caller body", "kind" => "win", "category" => "career" }
    )

    payload = JSON.parse(@last_kwargs[:message])
    assert_equal "persistent", payload["intensity"]
    assert payload["body"].start_with?("🏔️ ")
    assert_includes pool, payload["body"].delete_prefix("🏔️ ")
  end

  test "test kind keeps generic body from payload" do
    @user.create_notification_preference!(intensity: "normal")
    SendWebPushJob.perform_now(
      @user.id,
      {
        "title" => "LifePoints",
        "body" => "Push works. Your climb reminders can reach you here.",
        "kind" => "test"
      }
    )

    payload = JSON.parse(@last_kwargs[:message])
    assert_equal "Push works. Your climb reminders can reach you here.", payload["body"]
    assert_equal "normal", payload["intensity"]
  end
end
