# frozen_string_literal: true

require "test_helper"

class PushRemindersStatusContractTest < ActiveSupport::TestCase
  setup do
    @controller = Rails.root.join("app/javascript/controllers/push_reminders_controller.js").read
    @push = Rails.root.join("app/javascript/push_subscription.js").read
  end

  test "refreshState branches for granted subscribed setting-up default denied unsupported" do
    refresh = @controller[/async refreshState\(\)\s*\{[\s\S]*?\n  \}/]
    assert refresh.present?
    assert_includes refresh, 'state.permission === "granted" && state.subscribed'
    assert_includes refresh, "showSettingUpHint"
    assert_includes refresh, "repairPushSubscriptionIfNeeded"
    assert_includes refresh, "showDefaultHint"
    assert_includes refresh, 'state.permission === "denied"'
    assert_includes refresh, "showDeniedHint"
    assert_includes refresh, "showUnsupportedHint"
    assert_includes refresh, "canEnablePushHere()"
  end

  test "turnOn uses enable which requests permission then posts" do
    assert_includes @controller, "async turnOn(event)"
    assert_includes @controller, "await this.enable(event)"
    assert_includes @controller, "enablePushSubscription"
    enable = @controller[/async enable\(event\)\s*\{[\s\S]*?\n  \}/]
    assert enable.present?
    assert_includes enable, "enablePushSubscription"
    assert_includes @push, "Notification.requestPermission()"
    assert_includes @push, "completePushSubscription"
  end

  test "denied help fills browser name into apps step" do
    assert_includes @controller, "fillDeniedSteps"
    assert_includes @controller, "detectPushBrowserName"
    assert_includes @controller, 'appsTemplate.replace("%{browser}", browser)'
    assert_includes @push, "export function detectPushBrowserName"
    assert_includes @push, 'return "Samsung Internet"'
    assert_includes @push, 'return "your browser"'
  end

  test "unsupported shows chrome tip and android intent link" do
    assert_includes @controller, "showUnsupportedHint"
    assert_includes @controller, "unsupportedChromeMessage"
    assert_includes @controller, "chromeIntentHref"
    assert_includes @controller, "package=com.android.chrome"
    assert_includes @controller, "isAndroid()"
  end

  test "existing hooks stay wired" do
    assert_includes @controller, 'static targets = ['
    assert_includes @controller, '"enable"'
    assert_includes @controller, '"disable"'
    assert_includes @controller, '"switch"'
    assert_includes @controller, '"message"'
    assert_includes @controller, "toggleSwitch"
    assert_includes @controller, "sendTest"
    assert_includes @controller, "turnOn"
  end
end
