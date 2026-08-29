# frozen_string_literal: true

module Billing
  class ProcessWebhook
    HANDLED_EVENTS = %w[
      checkout.session.completed
      customer.subscription.updated
      customer.subscription.deleted
    ].freeze

    def self.call(event:)
      new(event:).call
    end

    def initialize(event:)
      @event = event
    end

    def call
      return :ignored unless HANDLED_EVENTS.include?(@event.type)
      return :duplicate if StripeWebhookEvent.exists?(stripe_event_id: @event.id)

      StripeWebhookEvent.transaction do
        StripeWebhookEvent.create!(
          stripe_event_id: @event.id,
          event_type: @event.type,
          processed_at: Time.current
        )
        handle_event
      end

      :processed
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => error
      raise unless duplicate_event?(error)

      :duplicate
    end

    private

    def handle_event
      case @event.type
      when "checkout.session.completed"
        handle_checkout_completed
      when "customer.subscription.updated", "customer.subscription.deleted"
        handle_subscription_event
      end
    end

    def handle_checkout_completed
      session = @event.data.object
      user = find_user(
        client_reference_id: session.client_reference_id,
        customer_id: session.customer
      )
      return unless user
      return if session.subscription.blank?

      subscription = Stripe::Subscription.retrieve(session.subscription)
      Billing::SyncSubscription.call(user:, subscription:)
    end

    def handle_subscription_event
      subscription = @event.data.object
      user = find_user(
        customer_id: subscription.customer,
        subscription_id: subscription.id
      )
      return unless user

      Billing::SyncSubscription.call(user:, subscription:)
    end

    def find_user(client_reference_id: nil, customer_id: nil, subscription_id: nil)
      if client_reference_id.present?
        user = User.find_by(id: client_reference_id)
        return user if user
      end

      if subscription_id.present?
        user = User.find_by(stripe_subscription_id: subscription_id)
        return user if user
      end

      if customer_id.present?
        return User.find_by(stripe_customer_id: customer_id)
      end

      nil
    end

    def duplicate_event?(error)
      case error
      when ActiveRecord::RecordNotUnique
        true
      when ActiveRecord::RecordInvalid
        error.record.is_a?(StripeWebhookEvent) &&
          error.record.errors.of_kind?(:stripe_event_id, :taken)
      else
        false
      end
    end
  end
end
