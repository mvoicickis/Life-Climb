import { Controller } from "@hotwired/stimulus"

// Click-time bounce + flat particle burst + optional "+N AP" float.
// When suppressReloadCelebrate is true (battle Win), set a sessionStorage
// flag so battle_day skips its post-reload celebrate (no double juice).
const SUPPRESS_KEY = "lpJuicySuppressCelebrate"

export default class extends Controller {
  static values = {
    suppressReloadCelebrate: { type: Boolean, default: false },
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

    event.preventDefault()
    if (this.playing) return
    this.playing = true

    const host = this.element.closest(".lp-dash-tcard, .lp-dash-checklist__obj") || this.element
    const amount = this.resolvedAmount(host)
    const popAmount = this.resolvedPopAmount()
    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches

    if (!reduceMotion) {
      this.bounce(host)
      this.burst(host)
      if (popAmount > 0) this.floatHabitPop(host, popAmount)
    }
    if (amount > 0) this.floatAp(host, amount)

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

  resolvedAmount(host) {
    const raw = host?.dataset?.lp || this.element.dataset.lp || "0"
    const n = Number.parseInt(raw, 10)
    return Number.isFinite(n) && n > 0 ? n : 0
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

  burst(host) {
    const root = document.createElement("div")
    root.className = "lp-juicy-burst"
    root.setAttribute("aria-hidden", "true")
    const colors = [ "#57d35b", "#f59e0b", "#38bdf8", "#f472b6", "#a3e635" ]
    for (let i = 0; i < 12; i += 1) {
      const bit = document.createElement("span")
      const angle = (Math.PI * 2 * i) / 12
      const dist = 28 + Math.random() * 36
      bit.style.setProperty("--x", `${Math.cos(angle) * dist}px`)
      bit.style.setProperty("--y", `${Math.sin(angle) * dist}px`)
      bit.style.setProperty("--d", `${380 + Math.random() * 220}ms`)
      bit.style.background = colors[i % colors.length]
      root.appendChild(bit)
    }
    host.appendChild(root)
    window.setTimeout(() => root.remove(), 800)
  }

  floatAp(host, amount) {
    const chip = document.createElement("span")
    chip.className = "lp-juicy-ap"
    chip.textContent = `+${amount} AP`
    host.appendChild(chip)
    requestAnimationFrame(() => chip.classList.add("is-shown"))
    window.setTimeout(() => chip.remove(), 900)
  }
}
