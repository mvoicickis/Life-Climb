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

  test "success stamps last_success_at" do
    assert_nil @subscription.last_success_at
    SendWebPushJob.perform_now(@user.id, { "title" => "Hi", "kind" => "test" })
    assert @subscription.reload.last_success_at.present?
  end

  test "destroys expired subscriptions and logs" do
    WebPush.define_singleton_method(:payload_send) do |**_kwargs|
      raise WebPush::ExpiredSubscription.new(FakeResponse.new("gone", "#<Fake 410>"), "push.example")
    end

    logs = capture_logs do
      assert_difference -> { PushSubscription.count }, -1 do
        SendWebPushJob.perform_now(@user.id, { "title" => "Hi" })
      end
    end

    assert_match(
      /\[SendWebPushJob\] expired user=#{@user.id} sub=#{@subscription.id} reason=WebPush::ExpiredSubscription/,
      logs
    )
  end

  test "destroys invalid subscriptions and logs" do
    WebPush.define_singleton_method(:payload_send) do |**_kwargs|
      raise WebPush::InvalidSubscription.new(FakeResponse.new("not found", "#<Fake 404>"), "push.example")
    end

    logs = capture_logs do
      assert_difference -> { PushSubscription.count }, -1 do
        SendWebPushJob.perform_now(@user.id, { "title" => "Hi" })
      end
    end

    assert_match(
      /\[SendWebPushJob\] expired user=#{@user.id} sub=#{@subscription.id} reason=WebPush::InvalidSubscription/,
      logs
    )
  end

  test "other errors stamp last_error fields and log" do
    WebPush.define_singleton_method(:payload_send) do |**_kwargs|
      raise StandardError, "upstream timeout"
    end

    logs = capture_logs do
      SendWebPushJob.perform_now(@user.id, { "title" => "Hi", "kind" => "test" })
    end

    @subscription.reload
    assert @subscription.last_error_at.present?
    assert_equal "StandardError: upstream timeout", @subscription.last_error
    assert_match(
      /\[SendWebPushJob\] error user=#{@user.id} sub=#{@subscription.id} StandardError: upstream timeout/,
      logs
    )
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

  test "payload includes signed token and action buttons" do
    SendWebPushJob.perform_now(@user.id, { "title" => "Hi", "kind" => "test" })
    payload = JSON.parse(@last_kwargs[:message])

    assert payload["token"].present?
    assert_equal @user, User.find_signed(payload["token"], purpose: :notification_action)
    assert_equal 2, payload["actions"].size
    assert_equal "quick_add", payload["actions"][0]["action"]
    assert payload["actions"][0]["title"].present?
  end

  test "actions use mark_done when a Today battle exists" do
    seed_climb!(@user, today_mission: "Ship it")
    assert @user.daily_todos.for_day(Date.current).exists?

    SendWebPushJob.perform_now(@user.id, { "title" => "Hi", "kind" => "win", "category" => "career" })
    payload = JSON.parse(@last_kwargs[:message])
    assert_equal %w[quick_add mark_done], payload["actions"].map { |a| a["action"] }
  end

  test "morning kind omits actions key" do
    @user.daily_todos.delete_all
    refute @user.daily_todos.for_day(Date.current).exists?

    SendWebPushJob.perform_now(@user.id, { "title" => "Hi", "kind" => "morning" })
    payload = JSON.parse(@last_kwargs[:message])
    refute payload.key?("actions")
  end

  # Phone check after deploy: open the installed PWA once (picks up SW v13), then
  # from a partner cheer Karen — she should get a heads-up with sound/vibrate. A
  # Settings test push should still look the same as before.
  test "high_five kind is visible with tag renotify vibrate and no actions" do
    @user.create_notification_preference!(intensity: "gentle")

    delivered = SendWebPushJob.perform_now(
      @user.id,
      {
        "title" => "Alex 🙌",
        "body" => "Alex high-fived your battle: Read 10 pages",
        "url" => "/dashboard",
        "kind" => "high_five",
        "tag" => "high_five",
        "icon" => "https://example.test/avatars/fox.png"
      }
    )

    assert delivered
    payload = JSON.parse(@last_kwargs[:message])
    assert_equal "Alex 🙌", payload["title"]
    assert_equal "Alex high-fived your battle: Read 10 pages", payload["body"]
    assert_equal "/dashboard", payload["url"]
    assert_equal "high_five", payload["kind"]
    assert_equal "high_five", payload["tag"]
    assert_equal true, payload["renotify"]
    assert_equal false, payload["silent"]
    assert_equal "normal", payload["intensity"]
    assert_equal [ 80, 40, 80, 40, 160 ], payload["vibrate"]
    assert_equal "https://example.test/avatars/fox.png", payload["icon"]
    assert_match(/\.png\z/, payload["icon"])
    refute payload.key?("actions")
  end

  test "admin_beta_signup has no actions and sends during quiet hours" do
    @user.create_notification_preference!(
      frequency: "off",
      time_zone: "UTC",
      quiet_hours_start: 0,
      quiet_hours_end: 23
    )

    travel_to Time.utc(2026, 8, 6, 23, 30, 0) do
      SendWebPushJob.perform_now(
        @user.id,
        {
          "title" => "New beta tester 🎉",
          "body" => "join@example.com",
          "url" => "/admin/beta_signups",
          "kind" => "admin_beta_signup",
          "tag" => "beta-signup-1"
        }
      )
    end

    assert_equal 1, @send_calls
    payload = JSON.parse(@last_kwargs[:message])
    assert_equal "join@example.com", payload["body"]
    assert_equal "admin_beta_signup", payload["kind"]
    assert_equal "/admin/beta_signups", payload["url"]
    assert_equal "beta-signup-1", payload["tag"]
    refute payload.key?("actions")
  end

  test "test kind still gets default actions and preference intensity" do
    @user.create_notification_preference!(intensity: "gentle")
    @user.daily_todos.delete_all

    SendWebPushJob.perform_now(
      @user.id,
      { "title" => "Life Climb", "body" => "Push works.", "url" => "/dashboard", "kind" => "test" }
    )
    payload = JSON.parse(@last_kwargs[:message])
    assert_equal "gentle", payload["intensity"]
    assert_equal %w[quick_add snooze], payload["actions"].map { |a| a["action"] }
    refute payload.key?("renotify")
    refute payload.key?("vibrate")
    refute payload.key?("silent")
  end

  test "high_five kind is blocked during quiet hours" do
    @user.create_notification_preference!(
      time_zone: "Europe/Berlin",
      quiet_hours_start: 22,
      quiet_hours_end: 7
    )

    travel_to Time.find_zone!("Europe/Berlin").local(2026, 11, 17, 23, 0, 0) do
      delivered = SendWebPushJob.perform_now(
        @user.id,
        { "title" => "Alex 🙌", "body" => "Cheered", "kind" => "high_five" }
      )
      refute delivered
      assert_equal 0, @send_calls
    end
  end

  test "high_five kind is blocked when frequency is off" do
    @user.create_notification_preference!(frequency: "off")

    delivered = SendWebPushJob.perform_now(
      @user.id,
      { "title" => "Alex 🙌", "body" => "Cheered", "kind" => "high_five" }
    )
    refute delivered
    assert_equal 0, @send_calls
  end

  test "high_five kind is blocked when vacation is active" do
    @user.create_notification_preference!(vacation_paused: true)

    delivered = SendWebPushJob.perform_now(
      @user.id,
      { "title" => "Alex 🙌", "body" => "Cheered", "kind" => "high_five" }
    )
    refute delivered
    assert_equal 0, @send_calls
  end

  test "evening kind sends empty actions and preserves copy" do
    delivered = SendWebPushJob.perform_now(
      @user.id,
      {
        "title" => "Get my driving license",
        "body" => "One small step before bed.",
        "kind" => "evening",
        "image" => "https://lifeclimb.app/images/push_mountain.webp"
      }
    )

    assert delivered
    payload = JSON.parse(@last_kwargs[:message])
    assert_equal "Get my driving license", payload["title"]
    assert_equal "https://lifeclimb.app/images/push_mountain.webp", payload["image"]
    assert_equal "One small step before bed.", payload["body"]
    refute payload.key?("actions")
  end

  test "morning kind preserves title and body" do
    delivered = SendWebPushJob.perform_now(
      @user.id,
      {
        "title" => "Get my driving license",
        "body" => "You wanted this. Go get it.",
        "kind" => "morning"
      }
    )

    assert delivered
    payload = JSON.parse(@last_kwargs[:message])
    assert_equal "Get my driving license", payload["title"]
    assert_equal "You wanted this. Go get it.", payload["body"]
    refute payload.key?("actions")
  end

  test "returns false when all subscriptions fail" do
    WebPush.define_singleton_method(:payload_send) do |**_kwargs|
      raise StandardError, "fail"
    end

    delivered = SendWebPushJob.perform_now(@user.id, { "title" => "Hi", "kind" => "test" })
    refute delivered
  end

  private

  def capture_logs
    io = StringIO.new
    previous = Rails.logger
    Rails.logger = Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = previous
  end
end
