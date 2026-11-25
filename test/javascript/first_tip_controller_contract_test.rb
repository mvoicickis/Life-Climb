# frozen_string_literal: true

require "test_helper"

class FirstTipControllerContractTest < ActiveSupport::TestCase
  setup do
    @source = Rails.root.join("app/javascript/controllers/first_tip_controller.js").read
    @layer = Rails.root.join("app/views/shared/_first_tip_layer.html.erb").read
  end

  test "controller posts ack on dismiss" do
    assert_includes @source, "ackUrl"
    assert_includes @source, "sendAck"
    assert_includes @source, "queueIdle"
    assert_includes @source, "waitForOverlaysIdle"
    assert_includes @source, "lp-overlay-idle"
    assert_includes @source, "teardownOverlayWait"
    refute_match(/attempt < 600/, @source)
    assert_includes @source, "guideInitial"
    assert_includes @source, 'closest(".lp-dash-nav")'
  end

  test "layer passes ack url data value" do
    assert_includes @layer, "data-first-tip-ack-url-value"
    assert_includes @layer, "first_tip_ack_path"
    assert_includes @layer, "data-first-tip-guide-initial-value"
    assert_includes @layer, "first_tip_guide_avatar_url"
  end
end
