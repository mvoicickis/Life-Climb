# frozen_string_literal: true

module Billing
  class CreateCheckoutSession
    LOOKUP_KEYS = {
      "monthly" => "premium_monthly",
      "yearly" => "premium_yearly"
    }.freeze

    class InvalidInterval < StandardError; end
    class PriceNotFound < StandardError; end

    def self.call(user:, interval:, success_url:, cancel_url:)
      new(user:, interval:, success_url:, cancel_url:).call
    end

    def initialize(user:, interval:, success_url:, cancel_url:)
      @user = user
      @interval = interval.to_s
      @success_url = success_url
      @cancel_url = cancel_url
    end

    def call
      lookup_key = LOOKUP_KEYS.fetch(@interval) { raise InvalidInterval }
      price = find_price!(lookup_key)
      customer_id = ensure_customer_id!

      session = Stripe::Checkout::Session.create(
        mode: "subscription",
        customer: customer_id,
        client_reference_id: @user.id.to_s,
        line_items: [ { price: price.id, quantity: 1 } ],
        success_url: @success_url,
        cancel_url: @cancel_url
      )

      { url: session.url }
    end

    private

    def find_price!(lookup_key)
      prices = Stripe::Price.list(lookup_keys: [ lookup_key ], active: true, limit: 1)
      price = prices.data.first
      raise PriceNotFound unless price

      price
    end

    def ensure_customer_id!
      return @user.stripe_customer_id if @user.stripe_customer_id.present?

      customer = Stripe::Customer.create(
        email: @user.email_address,
        metadata: { user_id: @user.id }
      )
      @user.update_columns(stripe_customer_id: customer.id)
      customer.id
    end
  end
end
