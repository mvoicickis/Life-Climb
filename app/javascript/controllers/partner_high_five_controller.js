import { Controller } from "@hotwired/stimulus"

// Today partner row: show "Not saved" if the high-five request fails.
export default class extends Controller {
  static targets = ["error"]
  static values = {
    notSaved: { type: String, default: "Not saved" }
  }

  submitEnd(event) {
    if (event.detail?.success) return
    if (!this.hasErrorTarget) return

    this.errorTarget.textContent = this.notSavedValue
    this.errorTarget.hidden = false
    this.errorTarget.classList.add("is-visible")
  }
}
