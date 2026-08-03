import { Controller } from "@hotwired/stimulus"

// Prevents double-tap on "Start my climb" while the (non-Turbo) POST is in flight.
export default class extends Controller {
  static targets = [ "submit" ]

  disable() {
    const button = this.hasSubmitTarget
      ? this.submitTarget
      : this.element.querySelector('[type="submit"]')
    if (!button || button.disabled) return

    button.disabled = true
    button.setAttribute("aria-busy", "true")
  }
}
