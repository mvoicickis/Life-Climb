// Shared press / haptic / confetti helpers. One burst implementation for
// juicy_feedback, battle_day, and strategy_celebrate.

import { play as playSound, isEnabled as soundEnabled } from "lib/lp_sound"

const TAP_BURST_KEY = "lpTapBurst"
const TAP_BURST_TTL_MS = 2500

const BURST_PRESETS = {
  juicy: {
    rootClass: "lp-juicy-burst",
    count: 12,
    colors: ["#57d35b", "#f59e0b", "#38bdf8", "#f472b6", "#a3e635"],
    distMin: 28,
    distSpread: 36,
    durationMin: 380,
    durationSpread: 220,
    removeMs: 800,
    xMode: "radial"
  },
  dash: {
    rootClass: "lp-dash-confetti",
    count: 18,
    bossCount: 28,
    durationMin: 420,
    durationSpread: 780,
    removeMs: 1300,
    xMode: "scatter",
    xSpread: 180,
    hue: true
  },
  strategy: {
    rootClass: "lp-strategy-confetti",
    count: 12,
    bossCount: 22,
    durationMin: 380,
    durationSpread: 650,
    removeMs: 1200,
    xMode: "scatter",
    xSpread: 160
  }
}

export function prefersReducedMotion() {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches
}

export function feelEnabled() {
  return soundEnabled()
}

function vibrate(ms) {
  try {
    const nav = navigator
    if (typeof nav.vibrate === "function") nav.vibrate(ms)
  } catch (_err) {
    // iOS / denied — silent
  }
}

export function hapticTap() {
  if (!feelEnabled() || prefersReducedMotion()) return
  vibrate(18)
}

export function hapticSuccess() {
  if (!feelEnabled() || prefersReducedMotion()) return
  vibrate([ 30, 50, 60 ])
}

export function haptic(ms = 12) {
  if (!feelEnabled() || prefersReducedMotion()) return
  vibrate(ms)
}

export function sound(name, options = {}) {
  playSound(name, options)
}

export function markTapBurst() {
  try {
    window.sessionStorage.setItem(TAP_BURST_KEY, String(Date.now()))
  } catch (_err) {
    window.__lpTapBurstAt = Date.now()
  }
}

export function consumeTapBurst() {
  let at = 0
  try {
    at = Number.parseInt(window.sessionStorage.getItem(TAP_BURST_KEY) || "0", 10) || 0
    window.sessionStorage.removeItem(TAP_BURST_KEY)
  } catch (_err) {
    at = window.__lpTapBurstAt || 0
    window.__lpTapBurstAt = 0
  }
  if (!at) return false
  return Date.now() - at < TAP_BURST_TTL_MS
}

export function burst(host, { density = "juicy", boss = false } = {}) {
  if (!host || prefersReducedMotion()) return
  const preset = BURST_PRESETS[density] || BURST_PRESETS.juicy
  const root = document.createElement("div")
  root.className = boss && preset.rootClass !== "lp-juicy-burst"
    ? `${preset.rootClass} is-boss`
    : preset.rootClass
  root.setAttribute("aria-hidden", "true")

  const count = boss && preset.bossCount ? preset.bossCount : preset.count
  for (let i = 0; i < count; i += 1) {
    const bit = document.createElement("span")
    if (preset.xMode === "radial") {
      const angle = (Math.PI * 2 * i) / count
      const dist = preset.distMin + Math.random() * preset.distSpread
      bit.style.setProperty("--x", `${Math.cos(angle) * dist}px`)
      bit.style.setProperty("--y", `${Math.sin(angle) * dist}px`)
    } else {
      bit.style.setProperty("--x", `${(Math.random() * preset.xSpread) - preset.xSpread / 2}px`)
    }
    bit.style.setProperty("--d", `${preset.durationMin + Math.random() * preset.durationSpread}ms`)
    if (preset.hue) {
      bit.style.setProperty("--h", `${85 + Math.random() * 45}`)
    }
    if (preset.colors) {
      bit.style.background = preset.colors[i % preset.colors.length]
    }
    root.appendChild(bit)
  }
  host.appendChild(root)
  window.setTimeout(() => root.remove(), preset.removeMs)
}

export default {
  haptic,
  hapticTap,
  hapticSuccess,
  feelEnabled,
  sound,
  burst,
  markTapBurst,
  consumeTapBurst,
  prefersReducedMotion
}
