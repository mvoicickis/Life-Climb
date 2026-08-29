# frozen_string_literal: true

require "test_helper"

module Billing
  class ProcessWebhookTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @secret = "whsec_test_webhook_secret"
    end

    test "updates user from customer.subscription.updated" do
      period_end = 1.month.from_now.to_i
      event = subscription_event(
        id: "evt_updated",
        type: "customer.subscription.updated",
        subscription_id: "sub_test",
        customer_id: "cus_test",
        status: "active",
        current_period_end: period_end
      )

      @user.update_columns(stripe_customer_id: "cus_test")

      assert_equal :processed, ProcessWebhook.call(event:)

      @user.reload
      assert_equal "sub_test", @user.stripe_subscription_id
      assert_equal "active", @user.subscription_status
      assert_equal Time.at(period_end).utc, @user.current_period_end
      assert @user.premium?
    end

    test "is idempotent for duplicate event delivery" do
      period_end = 1.month.from_now.to_i
      event = subscription_event(
        id: "evt_duplicate",
        type: "customer.subscription.updated",
        subscription_id: "sub_dup",
        customer_id: "cus_dup",
        status: "active",
        current_period_end: period_end
      )

      @user.update_columns(stripe_customer_id: "cus_dup")

      assert_equal :processed, ProcessWebhook.call(event:)

      travel 1.minute do
        @user.update_columns(updated_at: 1.minute.from_now)
        updated_at = @user.updated_at

        assert_equal :duplicate, ProcessWebhook.call(event:)
        assert_equal updated_at, @user.reload.updated_at
        assert_equal 1, StripeWebhookEvent.count
      end
    end

    test "syncs subscription from checkout.session.completed" do
      period_end = 1.month.from_now.to_i
      event = checkout_completed_event(
        id: "evt_checkout",
        user_id: @user.id,
        customer_id: "cus_checkout",
        subscription_id: "sub_checkout",
        status: "active",
        current_period_end: period_end
      )

      subscription = basil_subscription(
        customer: "cus_checkout",
        id: "sub_checkout",
        status: "active",
        current_period_end: period_end
      )

      with_singleton_stubs(
        Stripe::Subscription => { retrieve: ->(*) { subscription } }
      ) do
        assert_equal :processed, ProcessWebhook.call(event:)
      end

      @user.reload
      assert_equal "cus_checkout", @user.stripe_customer_id
      assert_equal "sub_checkout", @user.stripe_subscription_id
      assert @user.premium?
    end

    private

    def subscription_event(id:, type:, subscription_id:, customer_id:, status:, current_period_end:)
      Stripe::Event.construct_from(
        id:,
        object: "event",
        type:,
        data: {
          object: {
            id: subscription_id,
            object: "subscription",
            customer: customer_id,
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
          }
        }
      )
    end

    def checkout_completed_event(id:, user_id:, customer_id:, subscription_id:, status:, current_period_end:)
      Stripe::Event.construct_from(
        id:,
        object: "event",
        type: "checkout.session.completed",
        data: {
          object: {
            id: "cs_test",
            object: "checkout.session",
            client_reference_id: user_id.to_s,
            customer: customer_id,
            subscription: subscription_id
          }
        }
      )
    end

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
