# frozen_string_literal: true

module Billing
  class WebhooksController < ApplicationController
    allow_unauthenticated_access
    skip_forgery_protection
    skip_onboarding_check

    def create
      payload = request.body.read
      sig_header = request.env["HTTP_STRIPE_SIGNATURE"]

      event = Stripe::Webhook.construct_event(
        payload,
        sig_header,
        StripeConfig.webhook_signing_secret
      )

      Billing::ProcessWebhook.call(event:)
      head :ok
    rescue JSON::ParserError, Stripe::SignatureVerificationError
      head :bad_request
    end
  end
end
