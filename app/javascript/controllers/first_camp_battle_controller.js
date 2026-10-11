import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form",
    "titleField",
    "repeatField",
    "submit",
    "error"
  ]

  static values = {
    needTitle: String,
    notSaved: String
  }

  connect() {
    this.submitting = false
    this.syncSubmit()
  }

  titleKeydown(event) {
    if (event.key !== "Enter") return
    event.preventDefault()
    if (this.submitTarget?.disabled) return
    this.formTarget.requestSubmit()
  }

  syncSubmit() {
    if (!this.hasSubmitTarget || !this.hasTitleFieldTarget) return
    const enabled = this.titleFieldTarget.value.trim().length > 0 && !this.submitting
    this.submitTarget.disabled = !enabled
  }

  submit(event) {
    if (this.submitting) {
      event.preventDefault()
      return
    }

    if (this.formTarget.dataset.confirmed === "true") {
      this.formTarget.dataset.confirmed = "false"
      return
    }

    event.preventDefault()
    this.clearError()

    const title = this.titleFieldTarget.value.trim()
    if (!title) {
      this.showError(this.needTitleValue)
      return
    }

    this.formTarget.dataset.confirmed = "true"
    this.submitting = true
    this.syncSubmit()
    this.formTarget.requestSubmit()
  }

  saved(event) {
    this.submitting = false
    this.syncSubmit()

    if (!event.detail.success) {
      this.formTarget.dataset.confirmed = "false"
      if (!this.errorTarget?.textContent?.trim()) {
        this.showError(this.notSavedValue)
      }
      return
    }

    const reveal = this.application.getControllerForElementAndIdentifier(
      document.getElementById("mountain-trail"),
      "first-camp-reveal"
    )
    reveal?.finish()

    const trail = document.getElementById("mountain-trail")
    if (trail) {
      trail.setAttribute("data-trail-camp-sheet-reveal-pending-value", "false")
    }
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
    this.errorTarget.removeAttribute("hidden")
  }

  clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ""
    this.errorTarget.hidden = true
    this.errorTarget.setAttribute("hidden", "")
  }
}
