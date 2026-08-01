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
  }
}
