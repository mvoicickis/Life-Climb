# frozen_string_literal: true

class SendWebPushJob < ApplicationJob
  queue_as :default

  # payload: { "title" => "...", "body" => "...", "url" => "/dashboard", "kind" => "test" }
  def perform(user_id, payload)
    user = User.find_by(id: user_id)
    return unless user

    message = payload.is_a?(Hash) ? payload.deep_stringify_keys : {}
    json = message.to_json

    user.push_subscriptions.find_each do |subscription|
      send_to(subscription, json)
    end
  end

  private

  def send_to(subscription, message)
    WebPush.payload_send(
      message: message,
      endpoint: subscription.endpoint,
      p256dh: subscription.p256dh,
      auth: subscription.auth,
      vapid: {
        subject: VapidConfig.subject,
        public_key: VapidConfig.public_key,
        private_key: VapidConfig.private_key
      }
    )
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
    subscription.destroy
  rescue StandardError => e
    Rails.logger.warn("[SendWebPushJob] #{e.class}: #{e.message}")
  end
end
