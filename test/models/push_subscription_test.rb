# frozen_string_literal: true

require "test_helper"

class PushSubscriptionTest < ActiveSupport::TestCase
  test "requires endpoint p256dh and auth" do
    sub = PushSubscription.new(user: users(:one))
    assert_not sub.valid?
    assert_includes sub.errors[:endpoint], "can't be blank"
    assert_includes sub.errors[:p256dh], "can't be blank"
    assert_includes sub.errors[:auth], "can't be blank"
  end

  test "endpoint must be unique" do
    PushSubscription.create!(
      user: users(:one),
      endpoint: "https://push.example/unique-1",
      p256dh: "pk",
      auth: "auth"
    )

    dup = PushSubscription.new(
      user: users(:two),
      endpoint: "https://push.example/unique-1",
      p256dh: "pk2",
      auth: "auth2"
    )
    assert_not dup.valid?
    assert_includes dup.errors[:endpoint], "has already been taken"
  end

  test "touch_seen! updates last_seen_at and optional user_agent" do
    sub = PushSubscription.create!(
      user: users(:one),
      endpoint: "https://push.example/touch",
      p256dh: "pk",
      auth: "auth"
    )

    freeze_time do
      sub.touch_seen!(user_agent: "TestAgent/1.0")
      assert_equal Time.current, sub.last_seen_at
      assert_equal "TestAgent/1.0", sub.user_agent
    end
  end
end
