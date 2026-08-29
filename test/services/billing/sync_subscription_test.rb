# frozen_string_literal: true

require "test_helper"

module Billing
  class SyncSubscriptionTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
    end

    test "writes subscription fields from a basil-shaped subscription" do
      period_end = 1.month.from_now.to_i
      subscription = basil_subscription(
        customer: "cus_test",
        id: "sub_test",
        status: "active",
        current_period_end: period_end
      )

      assert Billing::SyncSubscription.call(user: @user, subscription:)

      @user.reload
      assert_equal "cus_test", @user.stripe_customer_id
      assert_equal "sub_test", @user.stripe_subscription_id
      assert_equal "active", @user.subscription_status
      assert_equal Time.at(period_end).utc, @user.current_period_end
      assert @user.premium?
    end

    test "is idempotent when called twice with the same subscription" do
      subscription = basil_subscription(
        customer: "cus_test",
        id: "sub_test",
        status: "active",
        current_period_end: 1.month.from_now.to_i
      )

      Billing::SyncSubscription.call(user: @user, subscription:)
      updated_at = @user.reload.updated_at

      travel 1.minute do
        refute Billing::SyncSubscription.call(user: @user, subscription:)
        assert_equal updated_at, @user.reload.updated_at
      end
    end

    test "leaves user non-premium when item period end is missing" do
      subscription = Stripe::Subscription.construct_from(
        id: "sub_test",
        object: "subscription",
        customer: "cus_test",
        status: "active",
        items: { object: "list", data: [ { object: "subscription_item" } ] }
      )

      Billing::SyncSubscription.call(user: @user, subscription:)

      @user.reload
      assert_nil @user.current_period_end
      refute @user.premium?
    end

    private

    def basil_subscription(customer:, id:, status:, current_period_end:)
      Stripe::Subscription.construct_from(
        id:,
        object: "subscription",
        customer:,
        status:,
        items: {
          object: "list",
          data: [
            {
              object: "subscription_item",
              current_period_end:
            }
          ]
        }
      )
    end
  end
end
