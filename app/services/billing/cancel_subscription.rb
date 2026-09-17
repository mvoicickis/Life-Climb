# frozen_string_literal: true

module Billing
  class CancelSubscription
    TERMINAL_STATUSES = %w[canceled incomplete_expired].freeze

    def self.call(user:)
      new(user:).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      return if skip_cancel?

      Stripe::Subscription.cancel(@user.stripe_subscription_id)
    end

    private

    def skip_cancel?
      @user.stripe_subscription_id.blank? ||
        TERMINAL_STATUSES.include?(@user.subscription_status.to_s)
    end
  end
end
