import { Controller } from "@hotwired/stimulus"

// Disable Anytime quantity Win until the amount field has a real value (including 0).
export default class extends Controller {
  static targets = ["amount", "submit"]

  connect() {
    this.sync()
  }

  sync() {
    if (!this.hasSubmitTarget || !this.hasAmountTarget) return

    const raw = this.amountTarget.value.trim()
    this.submitTarget.disabled = raw === ""
  }
}
