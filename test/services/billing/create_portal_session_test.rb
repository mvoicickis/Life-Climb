# frozen_string_literal: true

require "test_helper"

module Billing
  class CreatePortalSessionTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @previous_secret = ENV["STRIPE_SECRET_KEY"]
      ENV["STRIPE_SECRET_KEY"] = "sk_test_portal"
      Stripe.api_key = ENV["STRIPE_SECRET_KEY"]
    end

    teardown do
      ENV["STRIPE_SECRET_KEY"] = @previous_secret
      Stripe.api_key = StripeConfig.secret_key
    end

    test "creates portal session for existing customer" do
      @user.update_columns(stripe_customer_id: "cus_existing")
      session = Stripe::BillingPortal::Session.construct_from(
        id: "bps_test",
        object: "billing_portal.session",
        url: "https://billing.stripe.test/portal"
      )
      captured = {}

      with_singleton_stubs(
        Stripe::BillingPortal::Session => {
          create: ->(params) { captured.replace(params); session }
        }
      ) do
        result = CreatePortalSession.call(
          user: @user,
          return_url: "https://example.com/pricing"
        )

        assert_equal "https://billing.stripe.test/portal", result[:url]
        assert_equal "cus_existing", captured[:customer]
        assert_equal "https://example.com/pricing", captured[:return_url]
      end
    end

    test "raises when stripe customer is missing" do
      @user.update_columns(stripe_customer_id: nil)

      assert_raises(CreatePortalSession::MissingCustomer) do
        CreatePortalSession.call(user: @user, return_url: "https://example.com/pricing")
      end
    end
  end
end
