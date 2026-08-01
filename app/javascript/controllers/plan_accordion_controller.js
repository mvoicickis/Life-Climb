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

    // Keep Open in Today visible inside the fixed Mountain sheet.
    requestAnimationFrame(() => {
      const footer = opened.querySelector(".lp-rpg-plan-card__footer")
      ;(footer || opened).scrollIntoView({ block: "nearest", behavior: "smooth" })
    })
  }
}
