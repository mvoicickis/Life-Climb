# frozen_string_literal: true

require "test_helper"

# Source contract for climb-path polish (no JS unit runner in this app).
class ClimbPathControllerContractTest < ActiveSupport::TestCase
  setup do
    @source = Rails.root.join("app/javascript/controllers/climb_path_controller.js").read
  end

  test "tap haptic feature-detects navigator.vibrate rather than assuming it" do
    assert_match(/typeof nav\.vibrate === ["']function["']/, @source)
    assert_match(/nav\.vibrate\(/, @source)
    assert_match(/export function tapHaptic/, @source)
  end

  test "parallax uses rAF-coalesced translate3d and cleans up on disconnect" do
    assert_includes @source, "requestAnimationFrame"
    assert_includes @source, "translate3d"
    assert_includes @source, "teardownParallax"
    assert_includes @source, "passive: true"
    assert_match(/PARALLAX_CLAMP\s*=\s*32/, @source)
    refute_includes @source, "will-change"
    refute_match(/backgroundPosition|background-position/, @source)
    refute_match(/scenic\.style\.filter|\.filter\s*=/, @source)
  end

  test "entrance respects reduced motion and uses IntersectionObserver" do
    assert_includes @source, "IntersectionObserver"
    assert_includes @source, "prefers-reduced-motion"
    assert_includes @source, "is-visible"
  end
end
