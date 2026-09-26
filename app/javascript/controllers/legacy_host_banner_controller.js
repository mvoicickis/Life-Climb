import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "lpLegacyHostBannerSnoozeUntil"
const SNOOZE_MS = 3 * 24 * 60 * 60 * 1000

export default class extends Controller {
  connect() {
    if (this.isSnoozed()) return
    this.element.hidden = false
    this.element.removeAttribute("hidden")
  }

  snooze() {
    try {
      const until = new Date(Date.now() + SNOOZE_MS).toISOString()
      localStorage.setItem(STORAGE_KEY, until)
    } catch (_error) {
      /* private mode */
    }
    this.element.hidden = true
    this.element.setAttribute("hidden", "")
  }

  isSnoozed() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY)
      if (!raw) return false
      const until = Date.parse(raw)
      if (Number.isNaN(until)) return false
      return Date.now() < until
    } catch (_error) {
      return false
    }
  }
}
