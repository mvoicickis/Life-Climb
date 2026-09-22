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

  test "push handler syncs app badge from payload without notification tag" do
    assert_includes @source, "syncAppBadgeFromPayload"
    assert_includes @source, "navigator.setAppBadge"
    assert_includes @source, "navigator.clearAppBadge"
    refute_includes @source, "tag:"
  end

  test "notificationclick clears app badge before opening app" do
    assert_includes @source, "clearAppBadgeSafe"
  end

  test "cache version bumped for offline page cache" do
    assert_includes @source, 'CACHE_VERSION = "v9"'
    assert_includes @source, "PAGE_CACHE_NAME"
    assert_includes @source, "-pages"
  end

  test "documents match navigate destination document or Accept html" do
    assert_includes @source, 'request.mode === "navigate"'
    assert_includes @source, 'request.destination === "document"'
    assert_includes @source, 'accept.includes("text/html")'
  end

  test "full page documents skip turbo frame and turbo stream accept" do
    assert_includes @source, "isFullPageDocument"
    assert_includes @source, 'request.headers.get("Turbo-Frame")'
    assert_includes @source, "text/vnd.turbo-stream.html"
  end

  test "offline page cache only puts allowed dashboard and life journey paths" do
    network_fn = @source[/async function networkFirstOfflinePage[\s\S]*?(?=async function putPageCache)/]
    assert network_fn.present?, "expected networkFirstOfflinePage in the service worker"
    assert_includes network_fn, "isAllowedPageCachePath"
    assert_includes network_fn, "response.status === 200"
    assert_includes network_fn, "!response.redirected"
    assert_includes network_fn, "X-LP-No-Page-Cache"

    put_fn = @source[/async function putPageCache[\s\S]*?(?=async function matchPageCache)/]
    assert put_fn.present?, "expected putPageCache in the service worker"
    assert_includes put_fn, "cache.put"
    assert_includes @source, 'pathname === "/dashboard"'
    assert_includes @source, "/^\\/life_journeys\\/\\d+$/"
  end

  test "networkOnlyDocument never cache puts" do
    document_fn = @source[/async function networkOnlyDocument[\s\S]*?(?=async function offlineDocumentFallback)/]
    assert document_fn.present?, "expected networkOnlyDocument in the service worker"
    refute_includes document_fn, "cache.put"
  end

  test "static assets never cache html responses" do
    assert_includes @source, "application/xhtml+xml"
    assert_includes @source, "text/vnd.turbo-stream.html"
    assert_includes @source, "!isHtmlContentType(response)"
  end

  test "clear page cache message handler" do
    assert_includes @source, "CLEAR_PAGE_CACHE"
    assert_includes @source, "caches.delete(PAGE_CACHE_NAME)"
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
    assert_includes activate, "PAGE_CACHE_NAME"
    assert_includes activate, "await self.clients.claim()"
  end
end
