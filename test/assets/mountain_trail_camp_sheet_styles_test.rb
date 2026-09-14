# frozen_string_literal: true

require "test_helper"

class MountainTrailCampSheetStylesTest < ActiveSupport::TestCase
  setup do
    @css = Rails.root.join("app/assets/stylesheets/mountain_trail.css").read
    @tokens = Rails.root.join("app/assets/tailwind/application.css").read
  end

  test "camp sheet panel uses shared viewport variables and full height" do
    assert_includes @css, "--lp-sheet-vh"
    assert_includes @css, "--lp-keyboard-inset"
    assert_includes @css, "max-height: var(--lp-sheet-vh, 100dvh)"
    assert_includes @css, "height: var(--lp-sheet-vh, 100dvh)"
    refute_match(
      /\.lp-trail\.is-v4\.is-first-camp-reveal \.lp-trail-sheet__panel[\s\S]*?max-height:\s*82%/,
      @css
    )
  end

  test "camp sheet backdrop is non-interactive when full height" do
    assert_includes @css, ".lp-trail.is-v4 .lp-trail-sheet__backdrop"
    assert_includes @css, "pointer-events: none"
  end

  test "stage badge lift is clamped to half the gap to the terrace below" do
    assert_includes @css, "min(var(--lp-tent-fog-h) * 1.5, 0.5 * var(--trail-badge-gap"
  end

  test "frost token and fallback exist" do
    assert_includes @tokens, "--lp-frost"
    assert_includes @tokens, "@supports not (backdrop-filter: blur(1px))"
    assert_includes @tokens, ".lp-frost"
  end

  test "terraced map chrome scale is decoupled from photo zoom" do
    terraced = @css[/\.lp-trail\.is-terraced\s*\{[^}]+\}/m]
    assert terraced, "expected .lp-trail.is-terraced root block"
    assert_includes terraced, "--map-zoom: 1"
    assert_includes terraced, "--terrace-ui-scale: 0.9"
    assert_includes terraced, "--lp-pill-h: calc(23px * var(--terrace-ui-scale))"
    assert_includes terraced, "--lp-terrace-tap: var(--lp-tap"
  end

  test "terraced camp controls keep 44px tap targets with smaller drawn tents" do
    fog_hit = @css[/\.lp-trail\.is-terraced \.trail-tent-hit\s*\{[^}]+\}/m]
    assert fog_hit
    assert_includes fog_hit, "min-width: var(--lp-terrace-tap)"
    assert_includes fog_hit, "min-height: var(--lp-terrace-tap)"

    fog_after = @css[/\.lp-trail\.is-terraced \.trail-tent-hit::after\s*\{[^}]+\}/m]
    assert fog_after
    assert_includes fog_after, "width: var(--lp-terrace-tap)"
    refute_match(/terrace-ui-scale/, fog_after)

    open_camp = @css[/\.lp-trail\.is-terraced \.trail-t2-camp\s*\{[^}]+\}/m]
    assert open_camp
    assert_includes open_camp, "min-width: var(--lp-terrace-tap)"
    assert_includes open_camp, "min-height: var(--lp-terrace-tap)"
  end

  test "terraced map frost pills use lighter blur and shadow" do
    assert_includes @css, "backdrop-filter: blur(6px)"
    assert_includes @css, "box-shadow: 0 1px 3px rgba(15, 23, 42, 0.05)"

    current_caption = @css[/\.lp-trail\.is-terraced \.trail-t2-camp\.is-current \.lp-trail-camp__caption\s*\{[^}]+\}/m]
    assert current_caption
    assert_includes current_caption, "border: 1.5px solid"
    refute_includes current_caption, "0 0 12px"
  end
end
