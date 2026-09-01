import { Controller } from "@hotwired/stimulus"

// Optional one-tap submit for companion pickers (onboarding step 1).
export default class extends Controller {
  static values = { autoSubmit: { type: Boolean, default: false } }

  submit() {
    if (!this.autoSubmitValue) return

    const form = this.element.closest("form")
    if (form) form.requestSubmit()
  }
}
