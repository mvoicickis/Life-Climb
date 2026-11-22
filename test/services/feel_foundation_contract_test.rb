# frozen_string_literal: true

require "test_helper"

class FeelFoundationContractTest < ActiveSupport::TestCase
  setup do
    @css = Rails.root.join("app/assets/tailwind/application.css").read
    @today_css = Rails.root.join("app/assets/stylesheets/today_v2.css").read
    @streak_css = Rails.root.join("app/assets/stylesheets/streak_moment.css").read
    @you_css = Rails.root.join("app/assets/stylesheets/you_v2.css").read
    @mountain_css = Rails.root.join("app/assets/stylesheets/mountain_trail.css").read
    @feedback = Rails.root.join("app/javascript/lib/lp_feedback.js").read
    @sound = Rails.root.join("app/javascript/lib/lp_sound.js").read
    @juicy = Rails.root.join("app/javascript/controllers/juicy_feedback_controller.js").read
    @battle_day = Rails.root.join("app/javascript/controllers/battle_day_controller.js").read
    @strategy = Rails.root.join("app/javascript/controllers/strategy_celebrate_controller.js").read
    @pressable = Rails.root.join("app/javascript/controllers/pressable_controller.js").read
    @top_bar = Rails.root.join("app/javascript/controllers/today_top_bar_controller.js").read
    @application_js = Rails.root.join("app/javascript/application.js").read
  end

  test "motion tokens are defined on :root" do
    %w[
      --lp-motion-fast: 120ms
      --lp-motion-base: 200ms
      --lp-motion-slow: 320ms
      --lp-motion-celebrate: 500ms
      --lp-ease-out: cubic-bezier(0.22, 1, 0.36, 1)
      --lp-ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1)
      --lp-press-scale: 0.97
    ].each do |token|
      assert_includes @css, token
    end
  end

  test "hot paths use motion tokens" do
    assert_includes @css, "lp-vt-old-forward var(--lp-motion-slow)"
    assert_includes @css, "var(--lp-motion-celebrate)"
    assert_includes @css, "var(--lp-ease-out)"
    assert_includes @css, ".lp-toast"
    assert_match(/\.lp-toast[\s\S]*var\(--lp-motion-slow\)/, @css)
    assert_includes @today_css, "var(--lp-motion-fast)"
    assert_includes @today_css, "var(--lp-motion-base)"
    assert_includes @streak_css, "var(--lp-ease-out)"
    assert_includes @mountain_css, "var(--lp-motion-slow)"
  end

  test "pressable utility and reduced-motion kill exist" do
    assert_includes @css, ".lp-pressable"
    assert_includes @css, "scale(var(--lp-press-scale))"
    assert_match(/prefers-reduced-motion:\s*reduce[\s\S]*\.lp-pressable/, @css)
    assert_includes @pressable, 'classList.add("lp-pressable")'
    assert_includes @pressable, "hapticTap"
    assert_includes @today_css, "touch-action: manipulation"
    assert_includes @today_css, "scale(var(--lp-press-scale))"
  end

  test "haptic helpers respect feel switch and reduced motion" do
    assert_includes @feedback, "export function feelEnabled"
    assert_includes @feedback, "export function hapticTap"
    assert_includes @feedback, "export function hapticSuccess"
    assert_includes @feedback, "isEnabled as soundEnabled"
    assert_match(/if \(!feelEnabled\(\) \|\| prefersReducedMotion\(\)\) return/, @feedback)
    refute_includes @top_bar, "navigator.vibrate"
    assert_includes @top_bar, "hapticTap"
  end

  test "one confetti path and shared sound API" do
    assert_includes @feedback, "export function burst"
    assert_includes @feedback, "export function markTapBurst"
    assert_includes @feedback, "export function consumeTapBurst"
    assert_includes @juicy, 'burst(host, { density: "juicy" })'
    assert_includes @juicy, "markTapBurst()"
    assert_includes @juicy, "hapticSuccess()"
    assert_includes @battle_day, "consumeTapBurst()"
    assert_includes @battle_day, 'burst(this.element, { density: "dash"'
    assert_includes @battle_day, 'sound(this.bossValue ? "win_boss" : "win"'
    refute_includes @battle_day, "createOscillator"
    assert_includes @strategy, 'burst(this.element, { density: "strategy"'
    assert_includes @strategy, "sound("
    refute_includes @strategy, "createOscillator"
  end

  test "sound module respects setting and reduced motion" do
    assert_includes @sound, "lp-sound-enabled"
    assert_includes @sound, "prefers-reduced-motion"
    assert_includes @sound, "DEFAULT_VOLUME = 0.4"
    assert_includes @sound, "export function play"
    assert_includes @sound, "export function setEnabled"
    assert_match(/if \(!soundEnabled\(\) \|\| prefersReducedMotion\(\)\) return/, @sound)
  end

  test "play win builds mockup WIN DING oscillator sequence" do
    assert_includes @sound, "function playWinDing"
    assert_includes @sound, 'beep({ type: "triangle", freq: 440, dur: 0.18, vol: 0.1 * scale })'
    assert_includes @sound, 'beep({ type: "triangle", freq: 587, dur: 0.16, vol: 0.08 * scale })'
    assert_match(/setTimeout\(\(\) => \{\s*beep\(\{ type: "triangle", freq: 587/, @sound)
    assert_includes @sound, "}, 70)"
    assert_match(/if \(name === "win"\) \{\s*playWinDing\(vol\)/, @sound)
    # Sound off / reduced motion short-circuits before any oscillator work.
    refute_match(/if \(name === "win"\)[\s\S]*playWinDing[\s\S]*if \(!soundEnabled/, @sound)
  end

  test "reduced motion skips burst and you flash" do
    assert_includes @feedback, "prefersReducedMotion()"
    assert_match(/if \(!host \|\| prefersReducedMotion\(\)\) return/, @feedback)
    assert_match(/prefers-reduced-motion:\s*reduce[\s\S]*\.lp-you-row--flash/, @you_css)
  end

  test "hover transform rules are gated for touch" do
    assert_includes @css, "@media (hover: hover)"
    # Spot-check known sticky offenders are wrapped
    assert_match(/@media \(hover: hover\) \{\s*\.lp-dash-cta:hover/, @css)
    assert_match(/@media \(hover: hover\) \{\s*\.home-card:hover/, @css)
    assert_match(/@media \(hover: hover\) \{\s*\.lp-rpg-project:hover/, @css)
  end

  test "low-power ambient kill and streak scaleX" do
    assert_includes @application_js, "lp-low-power"
    assert_includes @application_js, "hardwareConcurrency"
    assert_includes @mountain_css, "html.lp-low-power"
    assert_includes @streak_css, "transform: scaleX(0)"
    assert_includes @streak_css, "transform: scaleX(1)"
  end
end
