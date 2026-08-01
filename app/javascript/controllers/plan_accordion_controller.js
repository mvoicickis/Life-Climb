import { Controller } from "@hotwired/stimulus"

// Single-open accordion for Today's Plan cards on Mountain.
export default class extends Controller {
  static targets = ["item"]

  toggle(event) {
    const opened = event.target
    if (!(opened instanceof HTMLDetailsElement) || !opened.open) return

    this.itemTargets.forEach((item) => {
      if (item !== opened && item.open) item.open = false
    })

    // Keep the briefing CTA visible inside the fixed Mountain sheet.
    requestAnimationFrame(() => {
      const cta = opened.querySelector(".lp-rpg-plan-card__cta")
      ;(cta || opened).scrollIntoView({ block: "nearest", behavior: "smooth" })
    })
  }
}
