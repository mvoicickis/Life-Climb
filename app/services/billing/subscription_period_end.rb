# frozen_string_literal: true

module Billing
  # Stripe Basil (2025-03-31+) moved current_period_end from Subscription to
  # SubscriptionItem. The installed stripe gem pins 2025-08-27.basil, so we read
  # from items and fall back to a top-level field only for older API shapes.
  module SubscriptionPeriodEnd
    module_function

    def from(subscription)
      timestamp = period_end_timestamp(subscription)
      return nil if timestamp.nil?

      Time.at(timestamp).utc
    end

    def period_end_timestamp(subscription)
      item_ends = subscription_items(subscription).filter_map { |item| item_end_timestamp(item) }
      return item_ends.max if item_ends.any?

      read_attribute(subscription, :current_period_end)
    end

    def subscription_items(subscription)
      items = read_attribute(subscription, :items)
      return [] unless items

      data = read_attribute(items, :data)
      Array(data)
    end

    def item_end_timestamp(item)
      read_attribute(item, :current_period_end)
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
