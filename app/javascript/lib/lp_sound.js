// Shared win/UI sounds. Oscillator "win" by default; optional asset URLs via meta.
// Unlock AudioContext on first user gesture; play() is no-op when sound is off
// or prefers-reduced-motion is set.

const DEFAULT_VOLUME = 0.4
const META_ENABLED = "lp-sound-enabled"
const META_URLS = "lp-sound-urls"

let ctx = null
let unlocked = false
let buffers = Object.create(null)
let loading = Object.create(null)
let enabledOverride = null

function metaContent(name) {
  return document.querySelector(`meta[name="${name}"]`)?.content
}

function soundEnabled() {
  if (enabledOverride !== null) return enabledOverride
  const raw = metaContent(META_ENABLED)
  if (raw == null || raw === "") return true
  return raw === "true" || raw === "1"
}

function prefersReducedMotion() {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches
}

function ensureContext() {
  if (ctx) return ctx
  const Ctx = window.AudioContext || window.webkitAudioContext
  if (!Ctx) return null
  ctx = new Ctx()
  return ctx
}

function unlock() {
  const audio = ensureContext()
  if (!audio) return
  if (audio.state === "suspended") {
    audio.resume().catch(() => {})
  }
  unlocked = true
  preloadConfigured()
}

function onFirstGesture() {
  unlock()
  window.removeEventListener("pointerdown", onFirstGesture, true)
  window.removeEventListener("keydown", onFirstGesture, true)
}

function armUnlock() {
  window.addEventListener("pointerdown", onFirstGesture, true)
  window.addEventListener("keydown", onFirstGesture, true)
}

function parseUrls() {
  const raw = metaContent(META_URLS)
  if (!raw) return {}
  try {
    return JSON.parse(raw) || {}
  } catch (_err) {
    return {}
  }
}

async function loadBuffer(name, url) {
  if (buffers[name] || loading[name] || !url) return
  const audio = ensureContext()
  if (!audio) return
  loading[name] = true
  try {
    const res = await fetch(url, { credentials: "same-origin" })
    if (!res.ok) return
    const data = await res.arrayBuffer()
    buffers[name] = await audio.decodeAudioData(data.slice(0))
  } catch (_err) {
    // Missing or blocked audio — fall back to synth for known names.
  } finally {
    loading[name] = false
  }
}

function preloadConfigured() {
  const urls = parseUrls()
  Object.keys(urls).forEach((name) => {
    loadBuffer(name, urls[name])
  })
}

function playBuffer(name, volume) {
  const audio = ensureContext()
  const buffer = buffers[name]
  if (!audio || !buffer) return false
  const src = audio.createBufferSource()
  const gain = audio.createGain()
  src.buffer = buffer
  gain.gain.value = volume
  src.connect(gain)
  gain.connect(audio.destination)
  src.start(0)
  return true
}

function playWinSynth({ boss = false, volume = DEFAULT_VOLUME } = {}) {
  const audio = ensureContext()
  if (!audio) return
  try {
    const osc = audio.createOscillator()
    const gain = audio.createGain()
    osc.type = "triangle"
    osc.frequency.value = boss ? 587.33 : 440
    gain.gain.value = 0.0001
    osc.connect(gain)
    gain.connect(audio.destination)
    const now = audio.currentTime
    const peak = Math.max(0.0001, volume * 0.1)
    gain.gain.exponentialRampToValueAtTime(peak, now + 0.02)
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.25)
    osc.start(now)
    osc.stop(now + 0.28)
  } catch (_err) {
    // optional
  }
}

function playStrategySynth({ boss = false, volume = DEFAULT_VOLUME } = {}) {
  const audio = ensureContext()
  if (!audio) return
  try {
    const osc = audio.createOscillator()
    const gain = audio.createGain()
    osc.type = "sine"
    osc.frequency.value = boss ? 523.25 : 392
    gain.gain.value = 0.0001
    osc.connect(gain)
    gain.connect(audio.destination)
    const now = audio.currentTime
    const peak = Math.max(0.0001, volume * 0.125)
    gain.gain.exponentialRampToValueAtTime(peak, now + 0.02)
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.28)
    osc.start(now)
    osc.stop(now + 0.3)
  } catch (_err) {
    // optional
  }
}

export function setEnabled(next) {
  enabledOverride = Boolean(next)
  const meta = document.querySelector(`meta[name="${META_ENABLED}"]`)
  if (meta) meta.content = enabledOverride ? "true" : "false"
}

export function isEnabled() {
  return soundEnabled() && !prefersReducedMotion()
}

export function play(name, { volume = DEFAULT_VOLUME, boss = false } = {}) {
  if (!soundEnabled() || prefersReducedMotion()) return
  unlock()
  const vol = Number.isFinite(volume) ? Math.min(1, Math.max(0, volume)) : DEFAULT_VOLUME

  if (playBuffer(name, vol)) return

  if (name === "win" || name === "win_boss") {
    playWinSynth({ boss: boss || name === "win_boss", volume: vol })
    return
  }
  if (name === "strategy" || name === "strategy_boss") {
    playStrategySynth({ boss: boss || name === "strategy_boss", volume: vol })
  }
}

armUnlock()

export default { play, setEnabled, isEnabled }
