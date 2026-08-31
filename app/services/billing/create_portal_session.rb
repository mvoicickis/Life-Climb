# frozen_string_literal: true

module Billing
  class CreatePortalSession
    class MissingCustomer < StandardError; end

    def self.call(user:, return_url:)
      new(user:, return_url:).call
    end

    def initialize(user:, return_url:)
      @user = user
      @return_url = return_url
    end

    def call
      customer_id = @user.stripe_customer_id
      raise MissingCustomer if customer_id.blank?

      session = Stripe::BillingPortal::Session.create(
        customer: customer_id,
        return_url: @return_url
      )

      { url: session.url }
    end
  end
end
