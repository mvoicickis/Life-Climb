# frozen_string_literal: true

require "test_helper"

class TodaySheetMotionContractTest < ActiveSupport::TestCase
  setup do
    @css = Rails.root.join("app/assets/stylesheets/today_v2.css").read
    @menu = Rails.root.join("app/javascript/controllers/tcard_menu_controller.js").read
  end

  test "today sheets rise with motion base and ease out under is-today-v2" do
    assert_includes @css, "/* Today feel — sheet open"
    assert_includes @css, "@keyframes lp-today-sheet-scrim-in"
    assert_includes @css, "@keyframes lp-today-sheet-rise-in"
    assert_includes @css, "@keyframes lp-today-sheet-dialog-in"
    assert_includes @css, "body:has(.lp-dash.is-today-v2) .lp-dash-habit__sheet.is-sheet-open"
    assert_includes @css, "body:has(.lp-dash.is-today-v2) .lp-dash-habit__scrim.is-sheet-open"
    assert_includes @css, ".lp-dash.is-today-v2 .lp-strategy-sheet[open]"
    assert_match(
      /\.lp-dash\.is-today-v2 \.lp-strategy-sheet\[open\] \.lp-strategy-sheet__panel[\s\S]*var\(--lp-motion-base\)/,
      @css
    )
    assert_match(
      /lp-today-sheet-rise-in[\s\S]*var\(--lp-motion-base\)[\s\S]*var\(--lp-ease-out\)/,
      @css
    )
  end

  test "tcard menu toggles is-sheet-open for portal sheets" do
    assert_includes @menu, "is-sheet-open"
    assert_includes @menu, "sheetLayerElements"
    assert_includes @menu, "requestAnimationFrame"
  end

  test "photo today reduced motion consolidates celebrate and sheet opens" do
    assert_includes @css, "/* Photo Today — reduced motion (consolidated) */"
    assert_includes @css, ".lp-dash.is-today-v2.is-today-photo .lp-today-v2-row__box.is-won"
    assert_includes @css, ".lp-dash.is-today-v2.is-today-photo .lp-strategy-sheet[open] .lp-strategy-sheet__panel"
    refute_match(
      /\/\* Photo Today — reduced motion \(consolidated\) \*\/[\s\S]*\/\* Photo Today — reduced motion \(consolidated\) \*\//m,
      @css
    )
  end
end
