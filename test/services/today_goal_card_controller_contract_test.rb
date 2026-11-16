# frozen_string_literal: true

require "test_helper"

# Source contract for photo Today goal-card collapse (no JS unit runner here).
class TodayGoalCardControllerContractTest < ActiveSupport::TestCase
  setup do
    @source = Rails.root.join("app/javascript/controllers/today_goal_card_controller.js").read
    @css = Rails.root.join("app/assets/stylesheets/today_v2.css").read
  end

  test "toggles is-collapsed past the scroll threshold and cleans up" do
    assert_match(/COLLAPSE_AT\s*=\s*24/, @source)
    assert_match(/COLLAPSED_CLASS\s*=\s*["']is-collapsed["']/, @source)
    assert_includes @source, "requestAnimationFrame"
    assert_includes @source, "cancelAnimationFrame"
    assert_includes @source, "passive: true"
    assert_includes @source, "lp-today-scroll__pad"
    assert_includes @source, "classList.toggle"
    assert_includes @source, "scrollTop"
    assert_includes @source, "removeEventListener"
    assert_match(/scrollTop\s*>\s*COLLAPSE_AT/, @source)
  end

  test "connect re-reads scroll so stream replace keeps collapsed state" do
    assert_includes @source, "connect()"
    assert_includes @source, "disconnect()"
    assert_includes @source, "syncCollapsed()"
    # connect must apply current scrollTop before the next scroll event
    connect_body = @source[ /connect\(\)\s*\{(.*)\n  \}/m, 1 ]
    assert connect_body.present?
    assert_includes connect_body, "addEventListener"
    assert_includes connect_body, "syncCollapsed()"
  end

  test "collapsed CSS folds the kicker and respects reduced motion" do
    assert_match(/\.lp-today-group-card--goal\.is-collapsed/, @css)
    assert_match(
      /\.lp-today-group-card--goal\.is-collapsed\s+\.lp-today-goal-kicker\s*\{[^}]*max-height:\s*0/m,
      @css
    )
    assert_includes @css, "prefers-reduced-motion: reduce"
    refute_match(/#[0-9a-fA-F]{3,8}/, @css[/\.lp-today-group-card--goal\.is-collapsed[\s\S]{0,400}/])
  end
end
