# frozen_string_literal: true

class SendWebPushJob < ApplicationJob
  queue_as :default

  # payload: { "title" => "...", "body" => "...", "url" => "/dashboard", "kind" => "test" }
  def perform(user_id, payload)
    user = User.find_by(id: user_id)
    return unless user

    message = payload.is_a?(Hash) ? payload.deep_stringify_keys : {}
    gate = NotificationGate.allow?(user: user, kind: message["kind"])
    unless gate.allowed?
      Rails.logger.info(
        "[NotificationGate] skip user=#{user.id} kind=#{message["kind"].inspect} reason=#{gate.reason}"
      )
      return
    end

    enrich_message!(user, message)
    json = message.to_json

    user.push_subscriptions.find_each do |subscription|
      send_to(subscription, json)
    end
  end

  private

  def enrich_message!(user, message)
    preference = user.notification_preference
    message["intensity"] = preference&.intensity.presence || "normal"

    kind = message["kind"].to_s
    return unless Notifications::PhraseBank::TRIGGERS.include?(kind)

    category = resolve_category(user, message)
    locale = user.locale.presence || I18n.default_locale
    message["body"] = Notifications::PhraseBank.body_for(
      kind: kind,
      category: category,
      locale: locale
    )
  end

  def resolve_category(user, message)
    raw = message["category"]
    return raw if Onboarding::Categories.valid_id?(raw)

    journey = user.primary_focused_journey || user.focused_journeys.first
    Onboarding::Categories.id_for_journey(journey)
  end

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
