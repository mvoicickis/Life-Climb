# frozen_string_literal: true

class SendWebPushJob < ApplicationJob
  queue_as :default

  HIGH_FIVE_VIBRATE = [ 80, 40, 80, 40, 160 ].freeze
  NO_ACTIONS_KINDS = %w[morning evening high_five].freeze

  # payload: { "title" => "...", "body" => "...", "url" => "/dashboard", "kind" => "test" }
  # Returns true when at least one subscription received the push.
  def perform(user_id, payload)
    user = User.find_by(id: user_id)
    return false unless user

    message = payload.is_a?(Hash) ? payload.deep_stringify_keys : {}
    gate = NotificationGate.allow?(user: user, kind: message["kind"])
    unless gate.allowed?
      Rails.logger.info(
        "[NotificationGate] skip user=#{user.id} kind=#{message["kind"].inspect} reason=#{gate.reason}"
      )
      return false
    end

    enrich_message!(user, message)
    json = message.to_json
    delivered = false

    user.push_subscriptions.find_each do |subscription|
      delivered = true if send_to(subscription, json)
    end

    delivered
  end

  private

  def enrich_message!(user, message)
    preference = user.notification_preference
    kind = message["kind"].to_s

    message["intensity"] =
      if kind == "high_five"
        "normal"
      else
        preference&.intensity.presence || "normal"
      end

    unless kind.in?(NO_ACTIONS_KINDS)
      if Notifications::PhraseBank::TRIGGERS.include?(kind)
        category = Onboarding::Categories.resolve_for(user: user, explicit: message["category"])
        locale = :en
        message["body"] = Notifications::PhraseBank.body_for(
          kind: kind,
          category: category,
          locale: locale
        )
      end
    end

    message["token"] = user.signed_id(purpose: :notification_action, expires_in: 30.days)

    # Never send actions: [] — omit the key so the SW does not pass an empty array.
    message.delete("actions")

    if kind == "high_five"
      message["silent"] = false
      message["vibrate"] = HIGH_FIVE_VIBRATE.dup
      message["renotify"] = true
      message["tag"] = message["tag"].presence || "high_five"
      return
    end

    return if kind.in?(%w[morning evening])

    I18n.with_locale(:en) do
      action_day = morning_action_day(user, kind)
      has_battle = user.daily_todos.for_day(action_day).exists?
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

  def morning_action_day(user, kind)
    return Date.current unless kind == "morning"

    zone = user.notification_preference&.time_zone
    return Date.current if zone.blank?

    Time.current.in_time_zone(zone).to_date
  rescue ArgumentError, TZInfo::InvalidTimezoneIdentifier
    Date.current
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
    true
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
    subscription.destroy
    false
  rescue StandardError => e
    Rails.logger.warn("[SendWebPushJob] #{e.class}: #{e.message}")
    false
  end
end
