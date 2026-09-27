# frozen_string_literal: true

module Notifications
  # Cron-driven evening nudge: subscribed users, local 19–21, once per local day, no battle wins.
  class EveningNudgeRun
    EVENING_HOURS = (19..21).freeze
    KIND = "evening"

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
        Today::DayShield.reconcile!(user: user)
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
      User.where(id: PushSubscription.select(:user_id))
    end

    def notify!(user)
      pref = user.notification_preference
      return false if pref.blank? || pref.time_zone.blank?

      local_time = Time.current.in_time_zone(pref.time_zone)
      return false unless EVENING_HOURS.cover?(local_time.hour)

      local_date = local_time.to_date
      return false if pref.last_evening_nudge_sent_on == local_date

      if BattleWinsOnLocalDate.any?(user: user, date: local_date, time_zone: pref.time_zone)
        return false
      end

      gate = NotificationGate.allow?(user: user, kind: KIND)
      return false unless gate.allowed?

      locale = user.locale.presence || I18n.default_locale
      copy = EveningNudgeCopy.for(user: user, date: local_date, locale: locale)

      badge = Today::BattleOpenCount.for(user: user, on: local_date)

      delivered = SendWebPushJob.perform_now(
        user.id,
        {
          "title" => copy.title,
          "body" => copy.body,
          "url" => "/dashboard",
          "kind" => KIND,
          "badge" => badge,
          "tag" => "daily-nudge"
        }
      )

      return false unless delivered

      pref.update!(last_evening_nudge_sent_on: local_date)
      true
    rescue ArgumentError, TZInfo::InvalidTimezoneIdentifier => e
      Rails.logger.warn("[EveningNudgeRun] skip user=#{user.id} #{e.class}: #{e.message}")
      false
    rescue StandardError => e
      Rails.logger.warn("[EveningNudgeRun] fail user=#{user.id} #{e.class}: #{e.message}")
      false
    end
  end
end
