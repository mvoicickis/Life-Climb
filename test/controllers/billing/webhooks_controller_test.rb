# frozen_string_literal: true

require "test_helper"

module Billing
  class WebhooksControllerTest < ActionDispatch::IntegrationTest
    setup do
      @secret = "whsec_test_webhook_secret"
      @previous_secret = ENV["STRIPE_WEBHOOK_SIGNING_SECRET"]
      ENV["STRIPE_WEBHOOK_SIGNING_SECRET"] = @secret
    end

    teardown do
      ENV["STRIPE_WEBHOOK_SIGNING_SECRET"] = @previous_secret
    end

    test "rejects invalid signature" do
      post billing_webhook_path,
           params: "{}",
           headers: { "Stripe-Signature" => "t=0,v1=bad" }

      assert_response :bad_request
    end

    test "accepts a valid signed event" do
      payload = {
        id: "evt_controller",
        object: "event",
        type: "customer.subscription.updated",
        data: {
          object: {
            id: "sub_ctrl",
            object: "subscription",
            customer: "cus_missing",
            status: "active",
            items: { object: "list", data: [] }
          }
        }
      }.to_json

      post_signed_webhook(payload)

      assert_response :success
      assert StripeWebhookEvent.exists?(stripe_event_id: "evt_controller")
    end

    private

    def post_signed_webhook(payload)
      timestamp = Time.current
      signature = Stripe::Webhook::Signature.compute_signature(timestamp, payload, @secret)
      header = Stripe::Webhook::Signature.generate_header(timestamp, signature)

      post billing_webhook_path,
           params: payload,
           headers: {
             "CONTENT_TYPE" => "application/json",
             "Stripe-Signature" => header
           }
    end
  end
end
