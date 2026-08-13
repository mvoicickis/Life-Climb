import { Controller } from "@hotwired/stimulus"

// Reliable press depth on iOS (CSS :active alone is flaky).
export default class extends Controller {
  press() {
    this.element.classList.add("is-pressed")
  }

  release() {
    this.element.classList.remove("is-pressed")
  }
}
