import { Controller } from "@hotwired/stimulus"

// Shows / hides numeric target + unit fields when “Track as a number?” is toggled.
export default class extends Controller {
  static targets = ["toggle", "fields"]

  connect() {
    this.sync()
  }

  toggle() {
    this.sync()
    // Float-create cards reposition on resize when open.
    window.dispatchEvent(new Event("resize"))
  }

  sync() {
    if (!this.hasToggleTarget || !this.hasFieldsTarget) return

    const on = this.toggleTarget.checked
    this.fieldsTarget.hidden = !on
    this.fieldsTarget.querySelectorAll("[data-quantity-required]").forEach((input) => {
      input.required = on
      if (!on) input.setCustomValidity("")
    })
  }
}
