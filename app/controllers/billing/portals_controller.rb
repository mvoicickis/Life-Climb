# frozen_string_literal: true

module Billing
  class PortalsController < ApplicationController
    skip_onboarding_check

    def create
      result = CreatePortalSession.call(
        user: current_user,
        return_url: pricing_url(**mailer_url_options)
      )

      render json: result
    rescue CreatePortalSession::MissingCustomer
      render json: { error: "missing_customer" }, status: :unprocessable_entity
    rescue Stripe::StripeError => e
      Rails.logger.error("[billing] Stripe portal error: #{e.message}")
      render json: { error: "stripe_error" }, status: :unprocessable_entity
    end

    private

    def mailer_url_options
      Rails.application.config.action_mailer.default_url_options
    end
  end
end
