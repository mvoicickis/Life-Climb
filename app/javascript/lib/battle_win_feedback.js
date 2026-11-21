import { prefersReducedMotion } from "lib/lp_feedback"

export function turboSubmitOk(event) {
  return event.detail?.success === true
}

// Points still store on win; never float "+N Battle strength" / "+50 AP" on the row.
export function floatBattleStrength(_host, _amount, _label) {
  // no-op — PR2 flies "+1" into the goal bar instead
}

const WIN_TICK_ORIGIN_KEY = "lpWinTickOrigin"
const WIN_TICK_TTL_MS = 4000

/** Capture the tick's screen rect at tap — streams may replace the row. */
export function storeWinTickOrigin(el) {
  if (!el || prefersReducedMotion()) return
  const box = el.getBoundingClientRect()
  if (!box.width && !box.height) return
  const payload = {
    at: Date.now(),
    x: box.left + box.width / 2,
    y: box.top + box.height / 2
  }
  try {
    window.sessionStorage.setItem(WIN_TICK_ORIGIN_KEY, JSON.stringify(payload))
  } catch (_err) {
    window.__lpWinTickOrigin = payload
  }
}

export function consumeWinTickOrigin() {
  let raw = null
  try {
    raw = window.sessionStorage.getItem(WIN_TICK_ORIGIN_KEY)
    window.sessionStorage.removeItem(WIN_TICK_ORIGIN_KEY)
  } catch (_err) {
    raw = window.__lpWinTickOrigin ? JSON.stringify(window.__lpWinTickOrigin) : null
    window.__lpWinTickOrigin = null
  }
  if (!raw) return null
  try {
    const data = JSON.parse(raw)
    if (!data || Date.now() - Number(data.at || 0) > WIN_TICK_TTL_MS) return null
    return { x: Number(data.x), y: Number(data.y) }
  } catch (_err) {
    return null
  }
}

export function todayGoalBarFill() {
  return document.querySelector("[data-today-goal-bar]")
}

/** Fly "+1" from stored tick into the camp bar, then shine. */
export function flyPlusOneIntoGoalBar() {
  if (prefersReducedMotion()) {
    shineGoalBar()
    return
  }
  const origin = consumeWinTickOrigin()
  const bar = todayGoalBarFill()
  if (!origin || !bar) {
    shineGoalBar()
    return
  }

  const shell = document.querySelector(".lp-today-photo-shell") || document.getElementById("today-dash-root") || document.body
  const shellBox = shell.getBoundingClientRect()
  const to = bar.getBoundingClientRect()
  const startX = origin.x - shellBox.left
  const startY = origin.y - shellBox.top
  const endX = to.left - shellBox.left + to.width * 0.72
  const endY = to.top - shellBox.top + to.height * 0.5

  const chip = document.createElement("span")
  chip.className = "lp-today-plus-fly"
  chip.textContent = "+1"
  chip.setAttribute("aria-hidden", "true")
  chip.style.left = `${startX}px`
  chip.style.top = `${startY}px`
  chip.style.setProperty("--dx", `${endX - startX}px`)
  chip.style.setProperty("--dy", `${endY - startY}px`)
  if (getComputedStyle(shell).position === "static") shell.style.position = "relative"
  shell.appendChild(chip)
  window.setTimeout(() => {
    chip.remove()
    shineGoalBar()
  }, 900)
}

export function shineGoalBar() {
  const bar = todayGoalBarFill()
  if (!bar) return
  bar.classList.remove("is-shine")
  void bar.offsetWidth
  bar.classList.add("is-shine")
  window.setTimeout(() => bar.classList.remove("is-shine"), 700)
}

export function rollbackTrailWinRow(row) {
  if (!row) return

  row.classList.remove("is-exiting", "is-ticking")
  delete row.dataset.winInFlight
  delete row.dataset.winAnimating
  row.querySelector(".lp-trail-battles__box")?.classList.remove("is-won")
}

export function rollbackTodayWinRow(row) {
  if (!row) return

  row.classList.remove("is-struck", "is-pending-won", "is-sliding", "is-won-row")
  row.style.transform = ""
  row.style.opacity = ""
  delete row.dataset.winInFlight
  row.removeAttribute("aria-busy")
  row.querySelector(".lp-today-v2-row__box")?.classList.remove("is-won")
}

export function showWinSaveNotice(host, message) {
  if (!host || !message) return

  clearWinSaveNotice(host)
  const notice = document.createElement("p")
  notice.className = "lp-battle-win-save-notice"
  notice.setAttribute("role", "status")
  notice.textContent = message
  host.classList.add("has-win-save-notice")
  host.appendChild(notice)
}

export function clearWinSaveNotice(host) {
  if (!host) return

  host.querySelector(".lp-battle-win-save-notice")?.remove()
  host.classList.remove("has-win-save-notice")
}

export function lockWinSubmit(host, locked) {
  if (!host) return

  if (locked) {
    host.dataset.winInFlight = "1"
    host.setAttribute("aria-busy", "true")
  } else {
    delete host.dataset.winInFlight
    host.removeAttribute("aria-busy")
  }
}

export function winSubmitHostFromForm(form) {
  return (
    form?.closest(".lp-today-v2-row") ||
    form?.closest(".lp-dash-tcard.is-habit.is-binary-tick") ||
    form?.closest(".lp-trail-battles__row") ||
    form
  )
}
