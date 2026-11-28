# frozen_string_literal: true

require "test_helper"

class FirstTipControllerContractTest < ActiveSupport::TestCase
  setup do
    @source = Rails.root.join("app/javascript/controllers/first_tip_controller.js").read
    @layer = Rails.root.join("app/views/shared/_first_tip_layer.html.erb").read
  end

  test "controller supports ack for non-circle give-up paths" do
    assert_includes @source, "ackUrl"
    assert_includes @source, "sendAck"
    assert_includes @source, "ackOnPlainDismiss"
    assert_includes @source, 'keyValue !== "circle"'
    assert_includes @source, "closeWithoutWin"
    assert_includes @source, "queueIdle"
    assert_includes @source, "waitForOverlaysIdle"
    assert_includes @source, "lp-overlay-idle"
    assert_includes @source, "teardownOverlayWait"
    refute_match(/attempt < 600/, @source)
    assert_includes @source, "guideInitial"
    assert_includes @source, 'closest(".lp-dash-nav")'
  end

  test "outside tap nudges every key without dismiss" do
    capture = @source[/captureClick\(event\) \{[\s\S]*?\n  \}/m]
    assert capture
    assert_includes capture, "nudgeRingPulse()"
    refute_includes capture, "dismissWithoutAckForCircle"
    refute_match(/else \{[\s\S]*?dismissSilently/m, capture)
    refute_match(/else \{[\s\S]*?this\.dismiss\(\)/m, capture)
    refute_includes capture, 'else if (this.keyValue === "circle")'
  end

  test "closeWithoutWin keeps circle silent on timeout and missing target" do
    close_without_win = @source[/closeWithoutWin\(\) \{[\s\S]*?\n  \}/m]
    assert close_without_win
    assert_includes close_without_win, 'keyValue === "circle"'
    assert_includes close_without_win, "dismissSilently"
    assert_includes close_without_win, "dismiss()"

    capture = @source[/captureClick\(event\) \{[\s\S]*?\n  \}/m]
    assert_includes capture, "closeWithoutWin()"

    wait_for_target = @source[/async waitForTarget\(\) \{[\s\S]*?\n  \}/m]
    assert_includes wait_for_target, "closeWithoutWin()"
  end

  test "skip is silent for circle and acks for other keys" do
    skip_fn = @source[/skip\(event\) \{[\s\S]*?\n  \}/m]
    assert skip_fn
    assert_includes skip_fn, 'keyValue === "circle"'
    assert_includes skip_fn, "dismissSilently()"
    assert_includes skip_fn, "dismiss()"
    refute_includes skip_fn, "sendAck"
  end

  test "target tap still posts ack via dismissAndAct" do
    section = @source[/captureClick\(event\) \{[\s\S]*?\n  \}/m]
    assert section
    assert_includes section, "dismissAndAct(target)"

    dismiss_and_act = @source[/dismissAndAct\(target\) \{[\s\S]*?\n  \}/m]
    assert dismiss_and_act
    assert_includes dismiss_and_act, "sendAck"
    assert_includes dismiss_and_act, 'key === "camp_sheet"'
    assert_includes dismiss_and_act, "field?.focus()"
    refute_includes dismiss_and_act, "ackOnPlainDismiss"
  end

  test "habit stage two give-up dismisses with ack when add target missing" do
    advance = @source[/async advanceHabitStage\(\) \{[\s\S]*?\n  \}/m]
    assert advance
    assert_includes advance, "stageTwoReady"
    assert_includes advance, "this.dismiss()"
  end

  test "layer passes ack url data value" do
    assert_includes @layer, "data-first-tip-ack-url-value"
    assert_includes @layer, "first_tip_ack_path"
    assert_includes @layer, "data-first-tip-guide-initial-value"
    assert_includes @layer, "first_tip_guide_avatar_url"
  end

  test "layer renders skip control for every tip" do
    refute_includes @layer, 'cfg[:key].to_s == "circle"'
    assert_includes @layer, "lp-first-tip__skip"
    assert_includes @layer, "click->first-tip#skip"
    assert_includes @layer, "first_tips.skip"
  end
end
