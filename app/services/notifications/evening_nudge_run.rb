# frozen_string_literal: true

module Notifications
  # Cron-driven evening nudge: subscribed users in local 19–21, once per local day, no battle wins.
  class EveningNudgeRun
    EVENING_HOURS = (19..21).freeze
    KIND = "evening"
    PUSH_IMAGE_PATH = "/images/push_mountain.webp"
    SENT_ON_COLUMN = :last_evening_nudge_sent_on

    Result = Struct.new(:considered, :sent, :skipped, keyword_init: true)

    def self.call
      new.call
    end

    def call
      considered = 0
      sent = 0
      skipped = 0

      NudgeCandidateScope.users(hours: EVENING_HOURS, sent_on_column: SENT_ON_COLUMN).find_each do |user|
        considered += 1
        if enqueue!(user)
          sent += 1
        else
          skipped += 1
        end
      end

      Result.new(considered: considered, sent: sent, skipped: skipped)
    end

    private

    def enqueue!(user)
      pref = user.notification_preference
      return false if pref.blank? || pref.time_zone.blank?

      local_time = Time.current.in_time_zone(pref.time_zone)
      return false unless EVENING_HOURS.cover?(local_time.hour)

      local_date = local_time.to_date

      if BattleWinsOnLocalDate.any?(user: user, date: local_date, time_zone: pref.time_zone)
        return false
      end

      gate = NotificationGate.allow?(user: user, kind: KIND)
      return false unless gate.allowed?

      locale = :en
      copy = EveningNudgeCopy.for(user: user, date: local_date, locale: locale)
      badge = Today::BattleOpenCount.for(user: user, on: local_date)

      return false unless claim_send_date!(pref, local_date)

      Today::DayShield.reconcile!(user: user)

      SendWebPushJob.perform_later(
        user.id,
        {
          "title" => copy.title,
          "body" => copy.body,
          "url" => "/dashboard",
          "kind" => KIND,
          "badge" => badge,
          "tag" => "daily-nudge",
          "image" => PushAssetUrl.call(PUSH_IMAGE_PATH)
        }
      )
      true
    rescue ArgumentError, TZInfo::InvalidTimezoneIdentifier => e
      Rails.logger.warn("[EveningNudgeRun] skip user=#{user.id} #{e.class}: #{e.message}")
      false
    rescue StandardError => e
      Rails.logger.warn("[EveningNudgeRun] fail user=#{user.id} #{e.class}: #{e.message}")
      false
    end

    def claim_send_date!(pref, local_date)
      column = SENT_ON_COLUMN.to_s
      NotificationPreference.where(id: pref.id)
                            .where("#{column} IS NULL OR #{column} != ?", local_date)
                            .update_all(column => local_date, updated_at: Time.current) == 1
    end
  end
end
