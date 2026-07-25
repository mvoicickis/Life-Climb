import { Controller } from "@hotwired/stimulus"

// Select orbit node for icon-only label reveal on narrow screens.
export default class extends Controller {
  static targets = ["node"]

  select(event) {
    this.nodeTargets.forEach((node) => node.classList.remove("is-selected"))
    event.currentTarget.classList.add("is-selected")
  }
}
