import { Controller } from "@hotwired/stimulus"

// Expands/collapses the remaining Today habit cards in place.
export default class extends Controller {
  static targets = ["extra", "button"]
  static values = {
    more: String,
    less: String
  }

  connect() {
    this.sync()
  }

  toggle() {
    if (!this.hasExtraTarget) return

    this.extraTarget.hidden = !this.extraTarget.hidden
    this.sync()
  }

  sync() {
    if (!this.hasButtonTarget || !this.hasExtraTarget) return

    const expanded = !this.extraTarget.hidden
    this.buttonTarget.setAttribute("aria-expanded", expanded ? "true" : "false")
    this.buttonTarget.textContent = expanded ? this.lessValue : this.moreValue
  }
}
