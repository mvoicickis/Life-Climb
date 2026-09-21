# frozen_string_literal: true

require "test_helper"

class LpDashNavStylesTest < ActiveSupport::TestCase
  setup do
    @mountain_css = Rails.root.join("app/assets/stylesheets/mountain_trail.css").read
    @app_css = Rails.root.join("app/assets/tailwind/application.css").read
  end

  test "v4 tab bar is solid surface with hairline border and no glass effects" do
    bar = @mountain_css[/\.lp-dash-nav\.is-v4\s*\{[^}]+\}/m]
    assert bar, "expected .lp-dash-nav.is-v4 block"

    assert_match(/background:\s*var\(--lp-surface\)/, bar)
    assert_match(/border-top:\s*1px solid var\(--lp-border\)/, bar)
    refute_match(/backdrop-filter/, bar)
    refute_match(/box-shadow/, bar)
  end

  test "v4 active tab has ink label and no background wash" do
    active = @mountain_css[/\.lp-dash-nav\.is-v4 \.lp-dash-nav__link\.is-active\s*\{[^}]+\}/m]
    assert active, "expected v4 active link block"

    assert_match(/color:\s*var\(--lp-ink\)/, active)
    assert_match(/font-weight:\s*800/, active)
    assert_match(/background:\s*transparent/, active)
    refute_match(/rgba\(87,\s*211,\s*91/, active)
  end

  test "global dash nav active rule does not set a green background" do
    global_active = @app_css[/\.lp-dash-nav__link\.is-active\s*\{[^}]+\}/m]
    assert global_active, "expected global .lp-dash-nav__link.is-active block"
    refute_match(/background:/, global_active)
  end

  test "mountain FAB uses green fill surface ring and card shadow" do
    fab = @mountain_css[/\.lp-dash-nav__fab\s*\{[^}]+\}/m]
    assert fab, "expected .lp-dash-nav__fab block"

    assert_match(/background:\s*var\(--lp-green\)/, fab)
    assert_match(/0 0 0 5px var\(--lp-surface\)/, fab)
    assert_match(/var\(--lp-shadow-card\)/, fab)
    refute_match(/linear-gradient/, fab)
  end

  test "v4 phone shell uses paper behind reserved nav band" do
    shell = @mountain_css[/\.lp-rpg\.is-v4-phone\s*\{[^}]+\}/m]
    assert shell, "expected .lp-rpg.is-v4-phone block"
    assert_match(/background:\s*var\(--lp-paper\)/, shell)
    refute_match(/#0b120e/, shell)
  end
end
