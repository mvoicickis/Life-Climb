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
    if Notifications::PhraseBank::TRIGGERS.include?(kind)
      category = Onboarding::Categories.resolve_for(user: user, explicit: message["category"])
      locale = user.locale.presence || I18n.default_locale
      message["body"] = Notifications::PhraseBank.body_for(
        kind: kind,
        category: category,
        locale: locale
      )
    end

    message["token"] = user.signed_id(purpose: :notification_action, expires_in: 30.days)
    I18n.with_locale(user.locale.presence || I18n.default_locale) do
      has_battle = user.daily_todos.for_day(Date.current).exists?
      second_action =
        if has_battle
          { "action" => "mark_done", "title" => I18n.t("notifications.actions.mark_done") }
        else
          { "action" => "snooze", "title" => I18n.t("notifications.actions.snooze") }
        end

      message["actions"] = [
        { "action" => "quick_add", "title" => I18n.t("notifications.actions.quick_add") },
        second_action
      ]
    end
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
