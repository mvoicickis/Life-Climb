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

  test "handleNotificationAction posts battle_id when present" do
    assert_includes @source, "battle_id: data.battle_id"
  end

  test "cache version bumped for snooze actions" do
    assert_includes @source, 'CACHE_VERSION = "v8"'
  end

  test "documents match navigate destination document or Accept html" do
    assert_includes @source, 'request.mode === "navigate"'
    assert_includes @source, 'request.destination === "document"'
    assert_includes @source, 'accept.includes("text/html")'
  end

  test "documents are network-only and never cache.put" do
    document_fn = @source[/async function networkOnlyDocument[\s\S]*?(?=async function networkOnlyNoStore)/]
    assert document_fn.present?, "expected networkOnlyDocument in the service worker"
    refute_includes document_fn, "cache.put"
    assert_includes @source, "application/xhtml+xml"
    assert_includes @source, "text/vnd.turbo-stream.html"
    assert_includes @source, "!isHtmlContentType(response)"
  end

  test "install skipWaiting runs even if precache fails" do
    install = @source[/self\.addEventListener\("install"[\s\S]*?(?=self\.addEventListener\("activate")/]
    assert install.present?, "expected install listener in the service worker"
    assert_includes install, "await cache.addAll(PRECACHE_URLS)"
    assert_includes install, "catch"
    assert_includes install, "await self.skipWaiting()"
  end

  test "activate deletes old lifepoints caches and claims clients" do
    activate = @source[/self\.addEventListener\("activate"[\s\S]*?(?=self\.addEventListener\("fetch")/]
    assert activate.present?, "expected activate listener in the service worker"
    assert_includes activate, 'key.startsWith("lifepoints-")'
    assert_includes activate, "caches.delete(key)"
    assert_includes activate, "await self.clients.claim()"
  end
end
