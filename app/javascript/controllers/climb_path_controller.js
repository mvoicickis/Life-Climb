import { Controller } from "@hotwired/stimulus"

// Vertical climb path — scroll the current (or selected) camp into view on load.
export default class extends Controller {
  static targets = ["current", "selected"]

  connect() {
    requestAnimationFrame(() => this.scrollToFocus())
  }

  scrollToFocus() {
    const el = this.hasSelectedTarget
      ? this.selectedTarget
      : (this.hasCurrentTarget ? this.currentTarget : null)
    if (!el) return

    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    el.scrollIntoView({
      block: "center",
      inline: "nearest",
      behavior: reduce ? "auto" : "smooth"
    })
  }
}
