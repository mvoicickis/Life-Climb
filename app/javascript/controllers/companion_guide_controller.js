import { Controller } from "@hotwired/stimulus"

// Prevents rapid double-tap on guide answers before the (non-Turbo) POST navigates.
// Server idempotency alone is not enough: a second POST can hit the *next* step.
//
// Disable is deferred: setting submitter.disabled synchronously inside the submit
// handler can cancel the navigation in some browsers (button greys out, no POST).
export default class extends Controller {
  disable(event) {
    const root = this.element

    // Keep the clicked submit's name/value in the POST for native form submits.
    // Must run synchronously — after navigation starts the form payload is fixed.
    const submitter = event?.submitter
    if (submitter && submitter.name && submitter.form === root) {
      const hidden = document.createElement("input")
      hidden.type = "hidden"
      hidden.name = submitter.name
      hidden.value = submitter.value
      root.appendChild(hidden)
    }

    // Defer disabling until after the browser has begun submitting the form.
    window.setTimeout(() => {
      root.querySelectorAll('button, input[type="submit"]').forEach((el) => {
        if (el.disabled) return
        el.disabled = true
        el.setAttribute("aria-busy", "true")
      })
    }, 0)
  }
}
