# frozen_string_literal: true

require "test_helper"

class MountainTrailCampSheetStylesTest < ActiveSupport::TestCase
  setup do
    @css = Rails.root.join("app/assets/stylesheets/mountain_trail.css").read
    @app_css = Rails.root.join("app/assets/tailwind/application.css").read
  end

  test "camp sheet panel is opaque while body stays transparent" do
    panel_block = @css[/\.lp-trail\.is-v4 \.lp-trail-sheet__panel\s*\{[^}]+\}/m]
    assert panel_block, "expected v4 camp sheet panel block"
    assert_match(/background:\s*var\(--lp-paper-soft\)/, panel_block)

    camp_bg = @css[/\.lp-trail\.is-v4 \.lp-trail-sheet__camp-bg\s*\{[^}]+\}/m]
    assert camp_bg, "expected v4 camp photo layer block"
    assert_match(/opacity:\s*1/, camp_bg)

    body_block = @css[/\.lp-trail\.is-v4 \.lp-trail-sheet__body\s*\{[^}]+\}/m]
    assert body_block, "expected v4 camp sheet body block"
    assert_match(/background:\s*transparent/, body_block)
    assert_match(/margin-top:\s*0/, body_block)
  end

  test "camp sheet text chrome uses opaque paper-soft without header supports glass" do
    header_block = @css[/\.lp-trail\.is-v4 \.lp-trail-sheet__header\s*\{[^}]+\}/m]
    assert header_block, "expected v4 camp sheet header block"
    assert_match(/background:\s*var\(--lp-paper-soft\)/, header_block)
    refute_match(
      /@supports[^{]+\{[^}]*\.lp-trail\.is-v4 \.lp-trail-sheet__header\s*\{/m,
      @css
    )

    open_row = @css[/\.lp-trail\.is-v4 \.lp-trail-battles__row\.is-open[\s\S]*?background:\s*var\(--lp-paper-soft\)/m]
    assert open_row, "expected opaque camp battle rows"

    base_row = @css[
      /\.lp-trail\.is-v4 \.lp-trail-base-sheet \.lp-trail-battles__row\.is-check[\s\S]*?background:\s*var\(--lp-paper-soft\)/m
    ]
    assert base_row, "expected base camp daily row block"

    idle = @css[/\.lp-trail\.is-v4 \.lp-trail-camp-idle\s*\{[^}]+\}/m]
    assert idle, "expected camp idle card block"
    assert_match(/background:\s*var\(--lp-surface\)/, idle)

    composer = @css[/\.lp-trail\.is-v4 \.lp-trail-battles__composer-form\s*\{[^}]+\}/m]
    assert composer, "expected composer form block"
    assert_match(/background:\s*var\(--lp-paper-soft\)/, composer)

    won_strip = @css[/\.lp-trail\.is-v4 \.lp-trail-battles__won-strip\s*\{[^}]+\}/m]
    assert won_strip, "expected won strip block"
    assert_match(/background:\s*var\(--lp-surface\)/, won_strip)
    assert_match(/border-radius:\s*var\(--lp-radius-pill\)/, won_strip)
  end

  test "lp-frost uses solid surface by default with glass only in supports" do
    assert_match(
      /\.lp-frost\s*\{\s*background:\s*var\(--lp-surface\);\s*\}/,
      @app_css
    )
    refute_match(
      /@supports not \(backdrop-filter: blur\(1px\)\)/,
      @app_css
    )
  end

  test "no media query narrows camp sheet panel below full width" do
    refute_match(
      /@media[^{]*\{[\s\S]*?\.lp-trail-sheet__panel[\s\S]*?max-width:\s*28rem/m,
      @css
    )
    refute_match(
      /@media[^{]*\{[\s\S]*?\.lp-trail-sheet__panel[\s\S]*?min\(100%\s*-\s*2rem/m,
      @css
    )

    panel_blocks = @css.scan(/\.lp-trail\.is-v4 \.lp-trail-sheet__panel\s*\{[^}]+\}/m)
    assert panel_blocks.any? { |block| block.match?(/width:\s*100%/) && block.match?(/max-width:\s*100%/) },
           "expected v4 camp sheet panel to use full width"
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

  test "fogged camps stay tappable without pointer-events none on the button" do
    fog = @css[/\.lp-trail-camp\.is-fogged\s*\{[^}]+\}/m]
    assert fog, "expected .lp-trail-camp.is-fogged block"
    refute_match(/pointer-events:\s*none/, fog)
  end

  test "base camp basics rows and dock composer use opaque paper-soft cards" do
    assert_match(
      /\.lp-trail\.is-v4 \.lp-trail-base-sheet \.lp-trail-battles__row\.is-basics[\s\S]*?background:\s*var\(--lp-paper-soft\)/m,
      @css
    )

    base_composer = @css[
      /\.lp-trail\.is-v4 \.lp-trail-base-sheet \.lp-trail-battles__composer\.is-dock\s*\{[^}]+\}/m
    ]
    assert base_composer, "expected v4 base camp dock composer block"
    assert_match(/background:\s*var\(--lp-paper-soft\)/, base_composer)

    section_label = @css[/\.lp-trail-base-sheet__section-label\s*\{[^}]+\}/m]
    assert section_label, "expected base camp section label block"
    assert_match(/color:\s*var\(--lp-ink\)/, section_label)
    assert_match(/text-shadow:[\s\S]*var\(--lp-paper\)/, section_label)
    refute_match(/text-transform:\s*uppercase/, section_label)
    refute_match(/background:/, section_label)
  end
end
