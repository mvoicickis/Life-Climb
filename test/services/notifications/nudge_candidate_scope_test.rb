# frozen_string_literal: true

require "test_helper"

module Notifications
  class NudgeCandidateScopeTest < ActiveSupport::TestCase
    test "rejects unknown kind" do
      assert_raises(ArgumentError) do
        NudgeCandidateScope.users(kind: :midnight, hours: (7..11))
      end
    end

    test "postgres window sql uses fixed morning dedupe columns" do
      scope = NudgeCandidateScope.subscribed_with_preferences
      scoped = NudgeCandidateScope.send(:apply_postgres_window, scope, hours: (7..11), kind: :morning)
      sql = scoped.to_sql

      assert_includes sql, "last_morning_nudge_sent_on"
      assert_includes sql, "timezone(notification_preferences.time_zone"
      assert_not_includes sql, "last_evening_nudge_sent_on"
    end

    test "postgres window sql uses fixed evening dedupe columns" do
      scope = NudgeCandidateScope.subscribed_with_preferences
      scoped = NudgeCandidateScope.send(:apply_postgres_window, scope, hours: (19..21), kind: :evening)
      sql = scoped.to_sql

      assert_includes sql, "last_evening_nudge_sent_on"
      assert_includes sql, "timezone(notification_preferences.time_zone"
      assert_not_includes sql, "last_morning_nudge_sent_on"
    end
  end
end
