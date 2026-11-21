export function turboSubmitOk(event) {
  return event.detail?.success === true
}

// Points still store on win; never float "+N Battle strength" / "+50 AP" on the row.
export function floatBattleStrength(_host, _amount, _label) {
  // no-op — PR2 adds "+1 into the goal bar" instead
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
