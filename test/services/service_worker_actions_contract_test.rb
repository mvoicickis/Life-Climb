# frozen_string_literal: true

require "test_helper"

class ServiceWorkerActionsContractTest < ActiveSupport::TestCase
  setup do
    @source = Rails.root.join("app/views/pwa/service-worker.js").read
  end

  test "defines quick_add and mark_done actions" do
    assert_includes @source, 'action: "quick_add"'
    assert_includes @source, 'action: "mark_done"'
    assert_includes @source, "actions: notificationActions(data)"
  end

  test "notificationclick branches on action and posts to endpoints" do
    assert_includes @source, 'action === "quick_add"'
    assert_includes @source, 'action === "mark_done"'
    assert_includes @source, "/notifications/quick_add"
    assert_includes @source, "/notifications/mark_done"
    assert_includes @source, "handleNotificationAction"
  end

  test "cache version bumped for actions" do
    assert_includes @source, 'CACHE_VERSION = "v6"'
  end
end
