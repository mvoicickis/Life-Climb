# frozen_string_literal: true

module Notifications
  # Cron-driven morning nudge: users without a Today battle, in local 7–9am.
  class MorningNudgeRun
    MORNING_HOURS = (7..9).freeze
    KIND = "morning"

    Result = Struct.new(:considered, :sent, :skipped, keyword_init: true)

    def self.call
      new.call
    end

    def call
      considered = 0
      sent = 0
      skipped = 0

      candidate_users.find_each do |user|
        considered += 1
        if notify!(user)
          sent += 1
        else
          skipped += 1
        end
      end

      Result.new(considered: considered, sent: sent, skipped: skipped)
    end

    private

    def candidate_users
      # Avoid SELECT DISTINCT users.* — Postgres can't DISTINCT on json columns.
      User.where(id: PushSubscription.select(:user_id))
    end

    def notify!(user)
      pref = user.notification_preference
      return false if pref.blank? || pref.time_zone.blank?

      local_time = Time.current.in_time_zone(pref.time_zone)
      return false unless MORNING_HOURS.cover?(local_time.hour)

      local_date = local_time.to_date
      return false if pref.last_morning_nudge_sent_on == local_date
      return false if user.daily_todos.for_day(Date.current).exists?

      gate = NotificationGate.allow?(user: user, kind: KIND)
      return false unless gate.allowed?

      locale = user.locale.presence || I18n.default_locale
      body = PhraseBank.morning_nudge(locale: locale)

      SendWebPushJob.perform_now(
        user.id,
        {
          "title" => I18n.t("notifications.actions.morning_title", locale: locale),
          "body" => body,
          "url" => "/dashboard",
          "kind" => KIND
        }
      )

      pref.update!(last_morning_nudge_sent_on: local_date)
      true
    rescue ArgumentError, TZInfo::InvalidTimezoneIdentifier => e
      Rails.logger.warn("[MorningNudgeRun] skip user=#{user.id} #{e.class}: #{e.message}")
      false
    end
  end
end
