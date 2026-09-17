# frozen_string_literal: true

require "test_helper"

class MountainTrailCampSheetStylesTest < ActiveSupport::TestCase
  setup do
    @css = Rails.root.join("app/assets/stylesheets/mountain_trail.css").read
    @app_css = Rails.root.join("app/assets/tailwind/application.css").read
  end

  test "camp sheet panel and body use solid backgrounds outside backdrop supports" do
    panel_block = @css[/\.lp-trail\.is-v4 \.lp-trail-sheet__panel\s*\{[^}]+\}/m]
    assert panel_block, "expected v4 camp sheet panel block"
    assert_match(/background:\s*var\(--lp-paper-soft\)/, panel_block)
    refute_match(/transparent/, panel_block)

    body_block = @css[/\.lp-trail\.is-v4 \.lp-trail-sheet__body\s*\{[^}]+\}/m]
    assert body_block, "expected v4 camp sheet body block"
    assert_match(/background:\s*var\(--lp-paper-soft\)/, body_block)
    refute_match(/background:\s*transparent/, body_block)

    frost_default = panel_block[/^\s*--lp-frost:\s*([^;]+);/m, 1]
    assert_includes frost_default, "--lp-surface"
    refute_match(/transparent/, frost_default)
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
end
