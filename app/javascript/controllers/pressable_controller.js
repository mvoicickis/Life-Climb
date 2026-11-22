import { Controller } from "@hotwired/stimulus"
import { hapticTap } from "lib/lp_feedback"

// Reliable press depth on iOS (CSS :active alone is flaky).
// Uses shared .lp-pressable / .is-pressed tokens.
export default class extends Controller {
  connect() {
    this.element.classList.add("lp-pressable")
    this.pressed = false
  }

  press(event) {
    event?.stopPropagation?.()
    this.element.classList.add("is-pressed")
    if (!this.pressed) {
      this.pressed = true
      hapticTap()
    }
  }

  release() {
    this.element.classList.remove("is-pressed")
    this.pressed = false
  }
}
