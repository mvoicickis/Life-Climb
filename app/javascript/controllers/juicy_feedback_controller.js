import { Controller } from "@hotwired/stimulus"
import {
  lockWinSubmit,
  rollbackTodayWinRow,
  showWinSaveNotice,
  clearWinSaveNotice,
  turboSubmitOk,
  winSubmitHostFromForm
} from "lib/battle_win_feedback"
import { burst, haptic, markTapBurst, prefersReducedMotion } from "lib/lp_feedback"

// Click-time bounce + flat particle burst. No "+N Battle strength" float on win.
// When suppressReloadCelebrate is true (battle Win), set sessionStorage so
// battle_day skips post-reload celebrate.
const SUPPRESS_KEY = "lpJuicySuppressCelebrate"

export default class extends Controller {
  static values = {
    suppressReloadCelebrate: { type: Boolean, default: false },
    deferReward: { type: Boolean, default: false },
    winNotSaved: { type: String, default: "" },
    delay: { type: Number, default: 500 },
    popAmount: { type: Number, default: 0 }
  }

  play(event) {
    if (this.allowNextSubmit) {
      this.allowNextSubmit = false
      return
    }

    // Quantified objective: first submit opens the amount dialog — don't delay.
    const qtyHost = this.element.closest("[data-controller~='quantity-complete']")
    if (qtyHost) {
      const qty = this.application.getControllerForElementAndIdentifier(qtyHost, "quantity-complete")
      if (qty && !qty.readyToSubmit) return
    }

    const rowHost = winSubmitHostFromForm(this.element)
    if (this.deferRewardValue && rowHost?.dataset?.winInFlight === "1") {
      event.preventDefault()
      return
    }

    event.preventDefault()
    if (this.playing) return
    this.playing = true

    const host = this.element.closest(".lp-dash-tcard, .lp-dash-checklist__obj, .lp-today-v2-row") || this.element
    const popAmount = this.resolvedPopAmount()
    const reduceMotion = prefersReducedMotion()
    const battleWin = this.deferRewardValue

    if (battleWin) haptic(12)

    if (!reduceMotion) {
      this.bounce(host)
      burst(host, { density: "juicy" })
      if (battleWin) markTapBurst()
      if (popAmount > 0) this.floatHabitPop(host, popAmount)
    }

    if (battleWin) {
      clearWinSaveNotice(rowHost)
      lockWinSubmit(rowHost, true)
      rowHost?.classList.add("is-struck")
      rowHost?.querySelector(".lp-today-v2-row__box")?.classList.add("is-won")
      this.allowNextSubmit = true
      this.playing = false
      window.requestAnimationFrame(() => {
        if (typeof this.element.requestSubmit === "function") {
          this.element.requestSubmit()
        } else {
          this.element.submit()
        }
      })
      return
    }

    if (this.suppressReloadCelebrateValue) {
      try {
        window.sessionStorage.setItem(SUPPRESS_KEY, "1")
      } catch (_err) {
        // storage unavailable — reload may double-celebrate once
      }
    }

    const wait = reduceMotion ? 0 : this.delayValue
    window.setTimeout(() => {
      this.allowNextSubmit = true
      this.playing = false
      if (typeof this.element.requestSubmit === "function") {
        this.element.requestSubmit()
      } else {
        this.element.submit()
      }
    }, wait)
  }

  winSubmitEnd(event) {
    if (!this.deferRewardValue) return

    const rowHost = winSubmitHostFromForm(event.target)
    lockWinSubmit(rowHost, false)
    this.playing = false

    if (turboSubmitOk(event)) {
      if (this.suppressReloadCelebrateValue) {
        try {
          window.sessionStorage.setItem(SUPPRESS_KEY, "1")
        } catch (_err) {
          // storage unavailable
        }
      }
      return
    }

    rollbackTodayWinRow(rowHost)
    const message = this.winNotSavedValue
    if (message && rowHost) showWinSaveNotice(rowHost, message)
  }

  resolvedPopAmount() {
    if (this.popAmountValue > 0) return this.popAmountValue
    const raw = this.element.dataset.popAmount || "0"
    const n = Number.parseFloat(raw)
    return Number.isFinite(n) && n > 0 ? n : 0
  }

  floatHabitPop(host, amount) {
    const chip = document.createElement("span")
    chip.className = "lp-habit-pop"
    chip.setAttribute("aria-hidden", "true")
    const label = Number.isInteger(amount) ? amount.toLocaleString() : String(amount)
    chip.textContent = `+${label}`
    host.appendChild(chip)
    window.setTimeout(() => chip.remove(), 900)
  }

  bounce(host) {
    host.classList.remove("is-juicy")
    void host.offsetWidth
    host.classList.add("is-juicy")
    window.setTimeout(() => host.classList.remove("is-juicy"), 700)
  }
}
