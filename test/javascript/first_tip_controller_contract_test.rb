# frozen_string_literal: true

require "test_helper"

class FirstTipControllerContractTest < ActiveSupport::TestCase
  setup do
    @source = Rails.root.join("app/javascript/controllers/first_tip_controller.js").read
    @layer = Rails.root.join("app/views/shared/_first_tip_layer.html.erb").read
  end

  test "controller posts ack on dismiss for non-circle tips" do
    assert_includes @source, "ackUrl"
    assert_includes @source, "sendAck"
    assert_includes @source, "ackOnPlainDismiss"
    assert_includes @source, 'keyValue !== "circle"'
    assert_includes @source, "queueIdle"
    assert_includes @source, "waitForOverlaysIdle"
    assert_includes @source, "lp-overlay-idle"
    assert_includes @source, "teardownOverlayWait"
    refute_match(/attempt < 600/, @source)
    assert_includes @source, "guideInitial"
    assert_includes @source, 'closest(".lp-dash-nav")'
  end

  test "circle outside tap and waitForTarget timeout dismiss without ack" do
    dismiss_silently = @source[/dismissSilently\(\) \{[\s\S]*?\n  \}/m]
    assert dismiss_silently
    refute_includes dismiss_silently, "sendAck"

    capture = @source[/captureClick\(event\) \{[\s\S]*?\n  \}/m]
    assert_includes capture, "dismissWithoutAckForCircle()"
    refute_includes capture, "this.dismiss()"

    wait_for_target = @source[/async waitForTarget\(\) \{[\s\S]*?\n  \}/m]
    assert_includes wait_for_target, "dismissWithoutAckForCircle()"
    refute_includes wait_for_target, "this.dismiss()"
  end

  test "circle target tap still posts ack via dismissAndAct" do
    section = @source[/captureClick\(event\) \{[\s\S]*?\n  \}/m]
    assert section
    assert_includes section, "dismissAndAct(target)"
    assert_includes section, "dismissWithoutAckForCircle()"
    dismiss_and_act = @source[/dismissAndAct\(target\) \{[\s\S]*?\n  \}/m]
    assert dismiss_and_act
    assert_includes dismiss_and_act, "sendAck"
    refute_includes dismiss_and_act, "ackOnPlainDismiss"
  end

  test "layer passes ack url data value" do
    assert_includes @layer, "data-first-tip-ack-url-value"
    assert_includes @layer, "first_tip_ack_path"
    assert_includes @layer, "data-first-tip-guide-initial-value"
    assert_includes @layer, "first_tip_guide_avatar_url"
  end
end
