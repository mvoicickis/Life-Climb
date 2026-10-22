# frozen_string_literal: true

module Notifications
  # Push subscribers in a local-time window who have not been nudged yet today (local date).
  module NudgeCandidateScope
    KINDS = %i[morning evening].freeze

    POSTGRES_LOCAL_HOUR_IN_WINDOW = <<~SQL.squish
      EXTRACT(
        HOUR FROM timezone(notification_preferences.time_zone, CURRENT_TIMESTAMP)
      ) BETWEEN ? AND ?
    SQL

    POSTGRES_NOT_SENT_TODAY = {
      morning: <<~SQL.squish,
        (
          notification_preferences.last_morning_nudge_sent_on IS NULL
          OR notification_preferences.last_morning_nudge_sent_on <> (
            timezone(notification_preferences.time_zone, CURRENT_TIMESTAMP)
          )::date
        )
      SQL
      evening: <<~SQL.squish,
        (
          notification_preferences.last_evening_nudge_sent_on IS NULL
          OR notification_preferences.last_evening_nudge_sent_on <> (
            timezone(notification_preferences.time_zone, CURRENT_TIMESTAMP)
          )::date
        )
      SQL
    }.freeze

    RUBY_PLUCK_COLUMNS = {
      morning: [
        "users.id",
        "notification_preferences.time_zone",
        "notification_preferences.last_morning_nudge_sent_on"
      ],
      evening: [
        "users.id",
        "notification_preferences.time_zone",
        "notification_preferences.last_evening_nudge_sent_on"
      ]
    }.freeze

    module_function

    def users(kind:, hours:)
      kind = kind.to_sym
      raise ArgumentError, "unsupported nudge kind: #{kind.inspect}" unless KINDS.include?(kind)

      scope = subscribed_with_preferences
      scope = apply_gate_sql_filters(scope)
      if postgresql?
        apply_postgres_window(scope, hours: hours, kind: kind)
      else
        apply_ruby_window(scope, hours: hours, kind: kind)
      end
    end

    def subscribed_with_preferences
      User.joins(:notification_preference)
          .where(id: PushSubscription.select(:user_id))
          .where.not(notification_preferences: { time_zone: [ nil, "" ] })
    end

    def apply_gate_sql_filters(scope)
      scope.where.not(notification_preferences: { frequency: "off", vacation_paused: true })
           .where(
             "notification_preferences.vacation_until IS NULL OR notification_preferences.vacation_until < ?",
             Date.current
           )
           .where(
             "notification_preferences.snoozed_until IS NULL OR notification_preferences.snoozed_until <= ?",
             Time.current
           )
    end

    def postgresql?
      ActiveRecord::Base.connection.adapter_name.match?(/postgres/i)
    end

    def apply_postgres_window(scope, hours:, kind:)
      dedupe_sql = POSTGRES_NOT_SENT_TODAY.fetch(kind) do
        raise ArgumentError, "unsupported nudge kind: #{kind.inspect}"
      end

      scope.where(POSTGRES_LOCAL_HOUR_IN_WINDOW, hours.begin, hours.end).where(dedupe_sql)
    end

    def apply_ruby_window(scope, hours:, kind:)
      pluck_columns = RUBY_PLUCK_COLUMNS.fetch(kind) do
        raise ArgumentError, "unsupported nudge kind: #{kind.inspect}"
      end

      rows = scope.pluck(*pluck_columns)
      eligible_ids = rows.filter_map do |user_id, time_zone, sent_on|
        next if time_zone.blank?

        local = Time.current.in_time_zone(time_zone)
        next unless hours.cover?(local.hour)

        local_date = local.to_date
        next if sent_on == local_date

        user_id
      rescue ArgumentError, TZInfo::InvalidTimezoneIdentifier
        nil
      end

      User.where(id: eligible_ids)
    end
  end
end
