# frozen_string_literal: true

# Stripe API keys for Checkout and webhooks. Prefer ENV in production;
# fall back to Rails credentials in development/test.
module StripeConfig
  module_function

  def secret_key
    ENV["STRIPE_SECRET_KEY"].presence ||
      Rails.application.credentials.dig(:stripe, :secret_key).presence
  end

  def webhook_signing_secret
    ENV["STRIPE_WEBHOOK_SIGNING_SECRET"].presence ||
      Rails.application.credentials.dig(:stripe, :webhook_signing_secret).presence
  end

  def configured?
    secret_key.present? && webhook_signing_secret.present?
  end
end
