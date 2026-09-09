# frozen_string_literal: true

require "test_helper"

class MountainTrailCampSheetStylesTest < ActiveSupport::TestCase
  setup do
    @css = Rails.root.join("app/assets/stylesheets/mountain_trail.css").read
  end

  test "camp sheet panel uses shared viewport variables for normal and first camp reveal" do
    assert_includes @css, "--lp-sheet-vh"
    assert_includes @css, "--lp-keyboard-inset"
    assert_includes @css, "calc(var(--lp-sheet-vh, 100dvh) * 0.9)"
    refute_match(
      /\.lp-trail\.is-v4\.is-first-camp-reveal \.lp-trail-sheet__panel[\s\S]*?max-height:\s*82%/,
      @css
    )
  end
end
