import { Controller } from "@hotwired/stimulus"

// Today V2 — tap anywhere on a battle row to tick (submits the check form).
export default class extends Controller {
  activate(event) {
    const target = event.target
    if (target.closest("button, input, a, dialog")) return

    const form = this.element.querySelector("form.lp-today-v2-row__check-form")
    if (!form) return

    if (typeof form.requestSubmit === "function") {
      form.requestSubmit()
    } else {
      form.submit()
    }
  }
}
