import { applyTurboStreamFromResponse } from "lib/apply_turbo_stream"

const queues = new Map()
let leaveListenersBound = false

const ROW_STATE_CLASSES = ["is-done", "is-over", "is-hit"]

// Mirrored in application_helper.rb (habit_progress_segments) — change both.
export function habitProgressSegments(percent, count = 16) {
  const p = percent == null ? 0 : Number(percent)
  const over = p > 100
  const capped = Math.min(p, 100)
  return Array.from({ length: count }, (_, i) => {
    const threshold = ((i + 1) * 100) / count
    if (capped >= threshold) return over ? "o" : "f"
    return ""
  })
}

// Mirrored in application_helper.rb (habit_today_row_state) — change both.
export function habitTodayRowState({ amount, goal, stretchGoal, metGoal, done }) {
  const tokens = []
  const progress =
    stretchGoal && goal > 0 ? Math.round((amount / goal) * 100) : null
  const over = progress != null && progress > 100
  const hit = progress != null && progress >= 100
  if (done || metGoal) tokens.push("is-done")
  if (over) tokens.push("is-over")
  if (hit && !over) tokens.push("is-hit")
  return tokens.join(" ")
}

export function formatAmount(amount) {
  const num = Number(amount)
  if (!Number.isFinite(num)) return "0"
  return num === Math.floor(num) ? String(Math.floor(num)) : String(num)
}

export function parseAmount(raw) {
  const text = String(raw ?? "").trim().replace(/,/g, "")
  if (text === "") return null
  const num = Number(text)
  if (!Number.isFinite(num) || num < 0) return null
  return num
}

function getQueue(habitId) {
  const id = Number(habitId)
  if (!queues.has(id)) {
    queues.set(id, {
      habitId: id,
      localTotal: 0,
      confirmedTotal: 0,
      inFlight: false,
      inFlightTotal: null,
      debounceTimer: null,
      setUrl: null,
      listeners: new Set(),
      failed: false
    })
  }
  return queues.get(id)
}

function isPending(q) {
  return q.inFlight || q.debounceTimer != null
}

function snapshot(q) {
  return {
    habitId: q.habitId,
    localTotal: q.localTotal,
    confirmedTotal: q.confirmedTotal,
    failed: q.failed,
    inFlight: q.inFlight
  }
}

function emit(q) {
  const snap = snapshot(q)
  q.listeners.forEach((listener) => listener(snap))
}

function bindLeaveFlush() {
  if (leaveListenersBound) return
  leaveListenersBound = true

  const flushAll = () => {
    queues.forEach((q) => flushQueue(q, { keepalive: true, applyStream: false }))
  }

  document.addEventListener("turbo:before-visit", flushAll)
  window.addEventListener("pagehide", flushAll)
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "hidden") flushAll()
  })
}

export function subscribe(habitId, listener, { amount, setUrl } = {}) {
  bindLeaveFlush()
  const q = getQueue(habitId)
  if (setUrl) q.setUrl = setUrl
  if (!isPending(q)) {
    const seed = Number(amount)
    const safe = Number.isFinite(seed) ? Math.max(0, seed) : 0
    q.localTotal = safe
    q.confirmedTotal = safe
  }
  q.listeners.add(listener)
  listener(snapshot(q))
  return () => {
    q.listeners.delete(listener)
  }
}

export function bump(habitId, delta, { debounceMs = 400, setUrl } = {}) {
  const q = getQueue(habitId)
  if (setUrl) q.setUrl = setUrl
  q.failed = false
  q.localTotal = Math.max(0, q.localTotal + Number(delta))
  emit(q)
  scheduleSave(q, debounceMs)
}

export function setTotal(habitId, total, { debounceMs = 0, setUrl } = {}) {
  const q = getQueue(habitId)
  if (setUrl) q.setUrl = setUrl
  q.failed = false
  q.localTotal = Math.max(0, Number(total))
  emit(q)
  scheduleSave(q, debounceMs)
}

export function retry(habitId) {
  const q = getQueue(habitId)
  q.failed = false
  scheduleSave(q, 0)
}

function scheduleSave(q, debounceMs) {
  if (q.debounceTimer) clearTimeout(q.debounceTimer)
  if (debounceMs > 0) {
    q.debounceTimer = setTimeout(() => {
      q.debounceTimer = null
      flushQueue(q, { keepalive: false, applyStream: true })
    }, debounceMs)
    return
  }
  flushQueue(q, { keepalive: false, applyStream: true })
}

function flushQueue(q, { keepalive, applyStream }) {
  if (q.debounceTimer) {
    clearTimeout(q.debounceTimer)
    q.debounceTimer = null
  }
  if (q.inFlight) return
  if (q.localTotal === q.confirmedTotal) return
  if (!q.setUrl) return

  void runSave(q, { keepalive, applyStream })
}

async function runSave(q, { keepalive, applyStream }) {
  if (q.inFlight) return
  if (q.localTotal === q.confirmedTotal) return

  const total = q.localTotal
  q.inFlight = true
  q.inFlightTotal = total
  q.failed = false
  emit(q)

  const token = document.querySelector("meta[name='csrf-token']")?.content
  const body = new FormData()
  body.append("authenticity_token", token || "")
  body.append("mode", "set")
  body.append("return_to", "today")
  body.append("daily_log[amount]", String(total))

  try {
    const response = await fetch(q.setUrl, {
      method: "POST",
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-CSRF-Token": token || ""
      },
      body,
      credentials: "same-origin",
      keepalive: Boolean(keepalive)
    })

    if (response.ok) {
      const savedTotal = total
      q.confirmedTotal = savedTotal
      if (applyStream && q.localTotal === savedTotal) {
        await applyTurboStreamFromResponse(response)
      }
      if (q.localTotal !== savedTotal) {
        q.inFlight = false
        q.inFlightTotal = null
        emit(q)
        flushQueue(q, { keepalive: false, applyStream: true })
        return
      }
    } else if (!keepalive) {
      q.localTotal = q.confirmedTotal
      q.failed = true
    }
  } catch (_err) {
    if (!keepalive) {
      q.localTotal = q.confirmedTotal
      q.failed = true
    }
  } finally {
    q.inFlight = false
    q.inFlightTotal = null
    emit(q)
    if (!keepalive && !q.failed && q.localTotal !== q.confirmedTotal) {
      flushQueue(q, { keepalive: false, applyStream: true })
    }
  }
}

export { ROW_STATE_CLASSES }
