# frozen_string_literal: true

module Billing
  # Single write path for subscription-backed user columns. Webhook handlers only.
  class SyncSubscription
    def self.call(user:, subscription:)
      new(user:, subscription:).call
    end

    def initialize(user:, subscription:)
      @user = user
      @subscription = subscription
    end

    def call
      attrs = {
        stripe_customer_id: customer_id,
        stripe_subscription_id: subscription_id,
        subscription_status: status,
        current_period_end: Billing::SubscriptionPeriodEnd.from(@subscription)
      }

      changed = attrs.reject { |column, value| @user.read_attribute(column) == value }
      return false if changed.empty?

      @user.update_columns(changed)
      true
    end

    private

    def customer_id
      read_attribute(@subscription, :customer)
    end

    def subscription_id
      read_attribute(@subscription, :id)
    end

    def status
      read_attribute(@subscription, :status)
    end

    def read_attribute(object, name)
      if object.respond_to?(name)
        object.public_send(name)
      elsif object.is_a?(Hash)
        object[name.to_s] || object[name]
      end
    end
  end
end
