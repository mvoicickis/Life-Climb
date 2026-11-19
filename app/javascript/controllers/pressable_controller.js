import { Controller } from "@hotwired/stimulus"

// Reliable press depth on iOS (CSS :active alone is flaky).
// Uses shared .lp-pressable / .is-pressed tokens.
export default class extends Controller {
  connect() {
    this.element.classList.add("lp-pressable")
  }

  press() {
    this.element.classList.add("is-pressed")
  }

  release() {
    this.element.classList.remove("is-pressed")
  }
}
