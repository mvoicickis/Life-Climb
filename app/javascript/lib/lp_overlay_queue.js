// Today overlay queue: finale → streak → climb-reward → push offer.
// Only one visible at a time; the next opens when the previous releases.

const ORDER = {
  finale: 10,
  streak: 20,
  climb_reward: 30,
  push_offer: 40
}

let active = null
const waiting = []

function sortWaiting() {
  waiting.sort((a, b) => (ORDER[a.kind] || 99) - (ORDER[b.kind] || 99))
}

function openNext() {
  if (active) return
  if (!waiting.length) return
  sortWaiting()
  active = waiting.shift()
  try {
    active.open?.()
  } catch (err) {
    console.error(err)
    const failed = active
    active = null
    failed?.onFail?.()
    openNext()
  }
}

/**
 * @param {string} kind
 * @param {{ open: Function, onFail?: Function }} handlers
 */
export function enqueue(kind, { open, onFail } = {}) {
  if (!kind || typeof open !== "function") return
  // Replace a pending entry of the same kind.
  const idx = waiting.findIndex((item) => item.kind === kind)
  if (idx >= 0) waiting.splice(idx, 1)
  if (active?.kind === kind) {
    // Already showing this kind — keep it; ignore duplicate enqueue.
    return
  }
  waiting.push({ kind, open, onFail })
  openNext()
}

export function release(kind) {
  if (active?.kind === kind) {
    active = null
    openNext()
    return
  }
  const idx = waiting.findIndex((item) => item.kind === kind)
  if (idx >= 0) waiting.splice(idx, 1)
}

export function isActive(kind) {
  return active?.kind === kind
}

export function hasPending(kind) {
  if (active?.kind === kind) return true
  return waiting.some((item) => item.kind === kind)
}

export function resetForTests() {
  active = null
  waiting.length = 0
}

export function queueIdle() {
  return active === null && waiting.length === 0
}

export default { enqueue, release, isActive, hasPending, resetForTests, queueIdle }
