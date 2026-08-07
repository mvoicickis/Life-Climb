import { Controller } from "@hotwired/stimulus"

// Prevents rapid double-tap on guide answers before the (non-Turbo) POST navigates.
// Server idempotency alone is not enough: a second POST can hit the *next* step.
export default class extends Controller {
  disable(event) {
    const root = this.element
    root.querySelectorAll('button, input[type="submit"]').forEach((el) => {
      if (el.disabled) return
      el.disabled = true
      el.setAttribute("aria-busy", "true")
    })

    // Keep the clicked submit's name/value in the POST for native form submits.
    const submitter = event?.submitter
    if (submitter && submitter.name && submitter.form === root) {
      const hidden = document.createElement("input")
      hidden.type = "hidden"
      hidden.name = submitter.name
      hidden.value = submitter.value
      root.appendChild(hidden)
    }
  }
}
