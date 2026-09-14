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
    assert_includes terraced, "--terrace-ui-scale: 0.85"
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
    open_pill = @css[/\.lp-trail\.is-terraced \.trail-open-pill\s*\{[^}]+\}/m]
    assert open_pill
    assert_includes open_pill, "backdrop-filter: blur(4px)"
    assert_includes open_pill, "box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04)"

    caption = @css[/\.lp-trail\.is-terraced \.trail-t2-camp \.lp-trail-camp__caption\s*\{[^}]+\}/m]
    assert caption
    assert_includes caption, "backdrop-filter: blur(4px)"
    assert_includes caption, "box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04)"

    current_caption = @css[/\.lp-trail\.is-terraced \.trail-t2-camp\.is-current \.lp-trail-camp__caption\s*\{[^}]+\}/m]
    assert current_caption
    assert_includes current_caption, "border: 1.5px solid"
    refute_includes current_caption, "0 0 12px"
  end

  test "terraced tent shadows use lighter opacity" do
    fog_tent = @css[/\.lp-trail\.is-terraced \.trail-tent-hit \.trail-tent\s*\{[^}]+\}/m]
    assert fog_tent
    assert_includes fog_tent, "filter: drop-shadow(0 1px 2px rgba(15, 23, 42, 0.12))"

    open_tent = @css[/\.lp-trail\.is-terraced \.trail-t2-camp \.lp-trail-camp__tent\s*\{[^}]+\}/m]
    assert open_tent
    assert_includes open_tent, "filter: drop-shadow(1px 1px 2px rgba(12, 22, 14, 0.22))"

    ground = @css[/\.lp-trail\.is-terraced \.trail-t2-camp \.lp-trail-camp__shadow\s*\{[^}]+\}/m]
    assert ground
    assert_includes ground, "background: rgba(20, 16, 10, 0.24)"
  end

  test "open terrace paging arrows sit outside tents inside map safe area" do
    prev = @css[/\.lp-trail\.is-terraced \.trail-terrace\.is-open \.trail-terrace-camps__arrow\.is-prev\s*\{[^}]+\}/m]
    next_arrow = @css[/\.lp-trail\.is-terraced \.trail-terrace\.is-open \.trail-terrace-camps__arrow\.is-next\s*\{[^}]+\}/m]
    assert prev
    assert next_arrow
    assert_includes prev, "var(--map-safe)"
    assert_includes next_arrow, "var(--map-safe)"
    refute_includes prev, "lp-tent-open-w"
    refute_includes next_arrow, "lp-tent-open-w"
    assert_includes prev, "var(--lp-terrace-tap)"
    assert_includes next_arrow, "var(--lp-terrace-tap)"
  end
end
