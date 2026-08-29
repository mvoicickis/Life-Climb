# frozen_string_literal: true

require "test_helper"

module Billing
  class SubscriptionPeriodEndTest < ActiveSupport::TestCase
    test "reads current_period_end from subscription items on basil API shape" do
      subscription = Stripe::Subscription.construct_from(
        id: "sub_test",
        object: "subscription",
        items: {
          object: "list",
          data: [
            {
              id: "si_test",
              object: "subscription_item",
              current_period_end: 1_700_000_000
            }
          ]
        }
      )

      assert_equal Time.at(1_700_000_000).utc, SubscriptionPeriodEnd.from(subscription)
    end

    test "uses the latest item period end when multiple items exist" do
      subscription = Stripe::Subscription.construct_from(
        id: "sub_test",
        object: "subscription",
        items: {
          object: "list",
          data: [
            { object: "subscription_item", current_period_end: 1_700_000_000 },
            { object: "subscription_item", current_period_end: 1_800_000_000 }
          ]
        }
      )

      assert_equal Time.at(1_800_000_000).utc, SubscriptionPeriodEnd.from(subscription)
    end

    test "returns nil when no item period end is present" do
      subscription = Stripe::Subscription.construct_from(
        id: "sub_test",
        object: "subscription",
        items: { object: "list", data: [ { object: "subscription_item" } ] }
      )

      assert_nil SubscriptionPeriodEnd.from(subscription)
    end
  end
end
