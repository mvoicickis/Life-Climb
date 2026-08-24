import { Controller } from "@hotwired/stimulus"

// Step 1 destination overlay — enable CTA when title present.
export default class extends Controller {
  static targets = ["input", "submit"]

  connect() {
    this.syncButton()
  }

  syncButton() {
    if (!this.hasSubmitTarget || !this.hasInputTarget) return
    const ready = (this.inputTarget.value || "").trim().length > 0
    this.submitTarget.disabled = !ready
    this.submitTarget.classList.toggle("is-ready", ready)
  }

  disable(event) {
    if (!this.hasSubmitTarget) return
    this.submitTarget.disabled = true
    this.submitTarget.classList.remove("is-ready")
  }
}
