# frozen_string_literal: true

require Rails.root.join("app/services/stripe_config")

if StripeConfig.secret_key.present?
  Stripe.api_key = StripeConfig.secret_key
end
