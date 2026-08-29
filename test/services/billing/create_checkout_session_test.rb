# frozen_string_literal: true

require "test_helper"

module Billing
  class CreateCheckoutSessionTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @previous_secret = ENV["STRIPE_SECRET_KEY"]
      ENV["STRIPE_SECRET_KEY"] = "sk_test_checkout"
      Stripe.api_key = ENV["STRIPE_SECRET_KEY"]
    end

    teardown do
      ENV["STRIPE_SECRET_KEY"] = @previous_secret
      Stripe.api_key = StripeConfig.secret_key
    end

    test "creates checkout session and stores new stripe customer id" do
      price = Stripe::Price.construct_from(id: "price_monthly", object: "price")
      customer = Stripe::Customer.construct_from(id: "cus_new", object: "customer")
      session = Stripe::Checkout::Session.construct_from(
        id: "cs_test",
        object: "checkout.session",
        url: "https://checkout.stripe.test/session"
      )
      price_list = Struct.new(:data).new([ price ])

      with_singleton_stubs(
        Stripe::Price => { list: ->(*) { price_list } },
        Stripe::Customer => { create: ->(*) { customer } },
        Stripe::Checkout::Session => { create: ->(*) { session } }
      ) do
        result = CreateCheckoutSession.call(
          user: @user,
          interval: "monthly",
          success_url: "https://example.com/success",
          cancel_url: "https://example.com/cancel"
        )

        assert_equal "https://checkout.stripe.test/session", result[:url]
        assert_equal "cus_new", @user.reload.stripe_customer_id
      end
    end

    test "reuses existing stripe customer id" do
      @user.update_columns(stripe_customer_id: "cus_existing")
      captured = {}

      price = Stripe::Price.construct_from(id: "price_yearly", object: "price")
      session = Stripe::Checkout::Session.construct_from(
        id: "cs_test",
        object: "checkout.session",
        url: "https://checkout.stripe.test/session"
      )
      price_list = Struct.new(:data).new([ price ])

      with_singleton_stubs(
        Stripe::Price => { list: ->(*) { price_list } },
        Stripe::Checkout::Session => {
          create: ->(params) { captured.replace(params); session }
        }
      ) do
        CreateCheckoutSession.call(
          user: @user,
          interval: "yearly",
          success_url: "https://example.com/success",
          cancel_url: "https://example.com/cancel"
        )
      end

      assert_equal "cus_existing", captured[:customer]
      assert_equal @user.id.to_s, captured[:client_reference_id]
    end
  end
end
