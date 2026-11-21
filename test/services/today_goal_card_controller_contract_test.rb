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
    assert_includes @source, "scrollTop"
    assert_includes @source, "removeEventListener"
    assert_match(/scrollTop\s*>\s*COLLAPSE_AT/, @source)
  end

  test "pad flag survives stream replace and connect applies it without transition flash" do
    assert_includes @source, "goalCardCollapsed"
    assert_match(/NO_TRANSITION_CLASS\s*=\s*["']is-no-transition["']/, @source)
    assert_includes @source, "readCollapsedPreference"
    assert_includes @source, "setCollapsed"
    assert_includes @source, "queueEnableTransitions"
    assert_includes @source, "silent: true"
    assert_includes @source, "classList.remove(NO_TRANSITION_CLASS)"

    connect_body = @source[/connect\(\)\s*\{(.*)\n  \}/m, 1]
    assert connect_body.present?
    assert_includes connect_body, "addEventListener"
    assert_includes connect_body, "readCollapsedPreference"
    assert_includes connect_body, "silent: true"
  end

  test "connect with true flag collapses; false stays expanded" do
    assert_includes @source, 'flag === "true"'
    assert_includes @source, 'flag === "false"'
    assert_match(/dataset\[PAD_FLAG\]\s*=\s*collapsed \? ["']true["'] : ["']false["']/, @source)
  end

  test "collapsed CSS tightens the goal strip and camp bar fill uses ink" do
    assert_match(/\.lp-today-group-card--goal\.is-collapsed/, @css)
    assert_match(
      /\.lp-today-group-card--goal\.is-collapsed\s+\.lp-today-goal-strip__title\s*\{[^}]*font-size:/m,
      @css
    )
    assert_match(
      /\.lp-today-group-card--goal \.lp-today-camp-bar__fill\s*\{[^}]*background:\s*var\(--lp-ink\)/m,
      @css
    )
    assert_match(
      /\.lp-today-group-card--goal \.lp-today-camp-bar\.is-glow\s*\{[^}]*var\(--lp-ink\)/m,
      @css
    )
    assert_includes @css, "is-no-transition"
    assert_includes @css, "prefers-reduced-motion: reduce"
    refute_match(/#[0-9a-fA-F]{3,8}/, @css[/\.lp-today-group-card--goal\.is-collapsed[\s\S]{0,400}/])
  end
end
