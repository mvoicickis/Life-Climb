# frozen_string_literal: true

module Billing
  class CheckoutsController < ApplicationController
    skip_onboarding_check

    def create
      result = CreateCheckoutSession.call(
        user: current_user,
        interval: params.require(:interval),
        success_url: pricing_url(billing: "success", **mailer_url_options),
        cancel_url: pricing_url(billing: "cancel", **mailer_url_options)
      )

      render json: result
    rescue CreateCheckoutSession::InvalidInterval
      render json: { error: "invalid_interval" }, status: :unprocessable_entity
    rescue CreateCheckoutSession::PriceNotFound
      render json: { error: "price_not_found" }, status: :unprocessable_entity
    rescue Stripe::StripeError => e
      Rails.logger.error("[billing] Stripe checkout error: #{e.message}")
      render json: { error: "stripe_error" }, status: :unprocessable_entity
    end

    private

    def mailer_url_options
      Rails.application.config.action_mailer.default_url_options
    end
  end
end
