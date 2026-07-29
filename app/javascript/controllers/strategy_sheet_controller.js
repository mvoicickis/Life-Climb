import { Controller } from "@hotwired/stimulus"

// Collapsible Mountain battle sheet — keep the climb visible by default.
export default class extends Controller {
  static targets = ["body", "toggle"]
  static values = { expanded: { type: Boolean, default: false } }

  connect() {
    this.sync()
  }

  toggle() {
    this.expandedValue = !this.expandedValue
  }

  expandedValueChanged() {
    this.sync()
  }

  sync() {
    if (this.hasBodyTarget) this.bodyTarget.hidden = !this.expandedValue
    if (this.hasToggleTarget) {
      this.toggleTarget.setAttribute("aria-expanded", this.expandedValue ? "true" : "false")
    }
    this.element.classList.toggle("is-expanded", this.expandedValue)
  }
}
