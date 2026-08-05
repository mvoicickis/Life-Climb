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
  end

  teardown do
    WebPush.define_singleton_method(:payload_send, @original_payload_send)
  end

  test "calls WebPush for each subscription" do
    called_with = nil
    WebPush.define_singleton_method(:payload_send) do |**kwargs|
      called_with = kwargs
      true
    end

    SendWebPushJob.perform_now(@user.id, { "title" => "Hi", "body" => "Test", "url" => "/dashboard" })

    assert called_with
    assert_equal @subscription.endpoint, called_with[:endpoint]
    assert_includes called_with[:message], "Hi"
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
  end
end
