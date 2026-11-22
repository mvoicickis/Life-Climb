# frozen_string_literal: true

require "test_helper"

class TodaySheetMotionContractTest < ActiveSupport::TestCase
  setup do
    @css = Rails.root.join("app/assets/stylesheets/today_v2.css").read
    @menu = Rails.root.join("app/javascript/controllers/tcard_menu_controller.js").read
    @dismiss = Rails.root.join("app/javascript/lib/lp_today_sheet_dismiss.js").read
    @quantity = Rails.root.join("app/javascript/controllers/quantity_complete_controller.js").read
    @quest = Rails.root.join("app/javascript/controllers/quest_steps_controller.js").read
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

  test "today sheets close with exit keyframes and is-sheet-closing" do
    assert_includes @css, "/* Today feel — sheet close"
    assert_includes @css, "@keyframes lp-today-sheet-scrim-out"
    assert_includes @css, "@keyframes lp-today-sheet-rise-out"
    assert_includes @css, "@keyframes lp-today-sheet-dialog-out"
    assert_includes @css, ".lp-dash-habit__scrim.is-sheet-closing"
    assert_includes @css, ".lp-dash-habit__sheet.is-sheet-closing"
    assert_includes @css, ".lp-strategy-sheet[open].is-sheet-closing"
    assert_match(
      /lp-today-sheet-rise-out[\s\S]*var\(--lp-motion-base\)[\s\S]*var\(--lp-ease-out\)/,
      @css
    )
  end

  test "tcard menu defers teardown until exit animation" do
    assert_includes @menu, "is-sheet-open"
    assert_includes @menu, "is-sheet-closing"
    assert_includes @menu, "closeAnimated"
    assert_includes @menu, "_closing"
    assert_includes @menu, "beginExitAnimation"
    assert_includes @menu, "finishClose"
    assert_includes @menu, "afterExitMotion"
    assert_includes @menu, "requestAnimationFrame"
  end

  test "dialogs dismiss with deferred close helper" do
    assert_includes @dismiss, "dismissDialogAnimated"
    assert_includes @dismiss, "afterExitMotion"
    assert_includes @dismiss, "is-sheet-closing"
    assert_includes @dismiss, "prefersReducedMotion"
    assert_includes @quantity, "dismissDialogAnimated"
    assert_includes @quest, "dismissDialogAnimated"
  end

  test "photo today reduced motion consolidates celebrate and sheet opens" do
    assert_includes @css, "/* Photo Today — reduced motion (consolidated) */"
    assert_includes @css, ".lp-dash.is-today-v2.is-today-photo .lp-today-v2-row__box.is-won"
    assert_includes @css, ".lp-dash.is-today-v2.is-today-photo .lp-strategy-sheet[open] .lp-strategy-sheet__panel"
    assert_includes @css, "is-sheet-closing"
    refute_match(
      /\/\* Photo Today — reduced motion \(consolidated\) \*\/[\s\S]*\/\* Photo Today — reduced motion \(consolidated\) \*\//m,
      @css
    )
  end
end