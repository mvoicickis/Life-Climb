# frozen_string_literal: true

require "test_helper"

class PushSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "create saves subscription for current user" do
    assert_difference -> { @user.push_subscriptions.count }, 1 do
      post push_subscription_path,
           params: {
             subscription: {
               endpoint: "https://push.example/device-a",
               p256dh: "p256dh-key",
               auth: "auth-key"
             }
           },
           as: :json
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert body["ok"]
    sub = @user.push_subscriptions.find_by!(endpoint: "https://push.example/device-a")
    assert_equal "p256dh-key", sub.p256dh
    assert_equal "auth-key", sub.auth
  end

  test "create reassigns endpoint from another user" do
    other = PushSubscription.create!(
      user: users(:two),
      endpoint: "https://push.example/shared-device",
      p256dh: "old",
      auth: "old"
    )

    post push_subscription_path,
         params: {
           subscription: {
             endpoint: "https://push.example/shared-device",
             p256dh: "new-pk",
             auth: "new-auth"
           }
         },
         as: :json

    assert_response :ok
    other.reload
    assert_equal @user.id, other.user_id
    assert_equal "new-pk", other.p256dh
  end

  test "destroy removes subscription by endpoint" do
    PushSubscription.create!(
      user: @user,
      endpoint: "https://push.example/to-remove",
      p256dh: "pk",
      auth: "auth"
    )

    assert_difference -> { @user.push_subscriptions.count }, -1 do
      delete push_subscription_path, params: { endpoint: "https://push.example/to-remove" }, as: :json
    end

    assert_response :success
    assert JSON.parse(response.body)["ok"]
  end

  test "test enqueues SendWebPushJob when subscribed" do
    PushSubscription.create!(
      user: @user,
      endpoint: "https://push.example/test-device",
      p256dh: "pk",
      auth: "auth"
    )

    assert_enqueued_with(job: SendWebPushJob) do
      post test_push_subscription_path, as: :json
    end

    assert_response :success
  end

  test "test fails without subscription" do
    post test_push_subscription_path, as: :json
    assert_response :unprocessable_entity
  end

  test "requires authentication" do
    sign_out
    post push_subscription_path,
         params: {
           subscription: {
             endpoint: "https://push.example/anon",
             p256dh: "pk",
             auth: "auth"
           }
         },
         as: :json
    assert_response :redirect
  end
end
