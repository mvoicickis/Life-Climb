import { Controller } from "@hotwired/stimulus"

// Subtle count-up for KPI numbers.
export default class extends Controller {
  static values = {
    to: Number,
    duration: { type: Number, default: 900 }
  }

  connect() {
    const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    const target = this.toValue
    if (prefersReduced || !Number.isFinite(target)) {
      this.element.textContent = this.format(target)
      return
    }

    const start = performance.now()
    const from = 0
    const tick = (now) => {
      const t = Math.min(1, (now - start) / this.durationValue)
      const eased = 1 - Math.pow(1 - t, 3)
      this.element.textContent = this.format(Math.round(from + (target - from) * eased))
      if (t < 1) requestAnimationFrame(tick)
    }
    requestAnimationFrame(tick)
  }

  format(n) {
    return new Intl.NumberFormat().format(n)
  }
}
