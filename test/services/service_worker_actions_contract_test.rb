# frozen_string_literal: true

require "test_helper"

class ServiceWorkerActionsContractTest < ActiveSupport::TestCase
  setup do
    @source = Rails.root.join("app/views/pwa/service-worker.js").read
  end

  test "defines quick_add mark_done and snooze action paths" do
    assert_includes @source, 'action: "quick_add"'
    assert_includes @source, 'action: "snooze"'
    assert_includes @source, "actions: notificationActions(data)"
    assert_includes @source, 'quick_add: "/notifications/quick_add"'
    assert_includes @source, 'mark_done: "/notifications/mark_done"'
    assert_includes @source, 'snooze: "/notifications/snooze"'
  end

  test "notificationclick routes known actions through handleNotificationAction" do
    assert_includes @source, "ACTION_PATHS[action]"
    assert_includes @source, "handleNotificationAction"
  end

  test "cache version bumped for snooze actions" do
    assert_includes @source, 'CACHE_VERSION = "v7"'
  end
end
