export function turboSubmitOk(event) {
  return event.detail?.success === true
}

export function floatBattleStrength(host, amount, label) {
  if (!host || amount <= 0) return

  const chip = document.createElement("span")
  chip.className = "lp-juicy-ap"
  chip.setAttribute("aria-hidden", "true")
  chip.textContent = `+${amount} ${label}`
  host.appendChild(chip)
  requestAnimationFrame(() => chip.classList.add("is-shown"))
  window.setTimeout(() => chip.remove(), 900)
}

export function rollbackTrailWinRow(row) {
  if (!row) return

  row.classList.remove("is-exiting", "is-ticking")
  delete row.dataset.winInFlight
  delete row.dataset.winAnimating
  row.querySelector(".lp-trail-battles__box")?.classList.remove("is-won")
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
    form?.closest(".lp-trail-battles__row") ||
    form
  )
}
