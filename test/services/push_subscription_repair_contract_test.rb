# frozen_string_literal: true

require "test_helper"

class PushSubscriptionRepairContractTest < ActiveSupport::TestCase
  setup do
    @source = Rails.root.join("app/javascript/push_subscription.js").read
    @offer = Rails.root.join("app/javascript/controllers/push_offer_controller.js").read
    @reminders = Rails.root.join("app/javascript/controllers/push_reminders_controller.js").read
  end

  test "repair helper skips when permission is not granted and never prompts" do
    assert_includes @source, "export async function repairPushSubscriptionIfNeeded"
    assert_includes @source, 'Notification.permission !== "granted"'
    assert_includes @source, 'skipped: "permission"'
    refute_includes @source[/export async function repairPushSubscriptionIfNeeded[\s\S]*\n\}/], "requestPermission"
  end

  test "repair helper posts existing subscription and subscribes when missing" do
    helper = @source[/export async function repairPushSubscriptionIfNeeded[\s\S]*\n\}/]
    assert helper.present?
    assert_includes helper, "pushManager.getSubscription()"
    assert_includes helper, "if (!subscription)"
    assert_includes helper, "pushManager.subscribe("
    assert_includes helper, "postSubscriptionToServer"
    assert_includes helper, "markPushRepairRan()"
    assert_includes helper, 'skipped: "already"'
    assert_includes @source, 'sessionStorage.setItem(PUSH_REPAIR_SESSION_KEY, "1")'
  end

  test "Today push-offer connect calls repair and no longer gates on standalone only" do
    assert_includes @offer, "repairPushSubscriptionIfNeeded"
    refute_includes @offer, "syncStandaloneSubscription"
    connect = @offer[/connect\(\)\s*\{[\s\S]*?\n  \}/]
    assert connect.present?
    assert_includes connect, "repairPushSubscriptionIfNeeded"
    refute_includes connect, "isStandalonePwa()"
  end

  test "You push-reminders refreshState repairs when granted without a subscription" do
    assert_includes @reminders, "repairPushSubscriptionIfNeeded"
    refresh = @reminders[/async refreshState\(\)\s*\{[\s\S]*?\n  \}/]
    assert refresh.present?
    assert_includes refresh, "repairPushSubscriptionIfNeeded"
    assert_includes refresh, 'state.permission === "granted" && !state.subscribed'
  end
end
