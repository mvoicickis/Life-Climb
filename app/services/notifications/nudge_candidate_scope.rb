# frozen_string_literal: true

module Notifications
  # Push subscribers in a local-time window who have not been nudged yet today (local date).
  module NudgeCandidateScope
    module_function

    def users(hours:, sent_on_column:)
      scope = subscribed_with_preferences
      scope = apply_gate_sql_filters(scope)
      if postgresql?
        apply_postgres_window(scope, hours: hours, sent_on_column: sent_on_column)
      else
        apply_ruby_window(scope, hours: hours, sent_on_column: sent_on_column)
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

    def apply_postgres_window(scope, hours:, sent_on_column:)
      column = sent_on_column.to_s
      scope.where(
        <<~SQL.squish,
          EXTRACT(
            HOUR FROM timezone(notification_preferences.time_zone, CURRENT_TIMESTAMP)
          ) BETWEEN ? AND ?
          AND (
            notification_preferences.#{column} IS NULL
            OR notification_preferences.#{column} <> (
              timezone(notification_preferences.time_zone, CURRENT_TIMESTAMP)
            )::date
          )
        SQL
        hours.begin,
        hours.end
      )
    end

    def apply_ruby_window(scope, hours:, sent_on_column:)
      rows = scope.pluck(
        "users.id",
        "notification_preferences.time_zone",
        "notification_preferences.#{sent_on_column}"
      )
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
