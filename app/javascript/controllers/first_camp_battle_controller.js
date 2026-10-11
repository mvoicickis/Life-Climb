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
    const form = this.formTarget

    if (form.dataset.confirmed === "1") {
      delete form.dataset.confirmed
      return
    }

    if (this.submitting) {
      event.preventDefault()
      return
    }

    event.preventDefault()
    this.clearError()

    const title = this.titleFieldTarget.value.trim()
    if (!title) {
      this.showError(this.needTitleValue)
      return
    }

    form.dataset.confirmed = "1"
    this.submitting = true
    this.syncSubmit()

    window.requestAnimationFrame(() => {
      try {
        if (typeof form.requestSubmit === "function") {
          form.requestSubmit()
        } else {
          form.submit()
        }
      } catch (error) {
        delete form.dataset.confirmed
        this.submitting = false
        this.syncSubmit()
        throw error
      }
    })
  }

  saved(event) {
    this.submitting = false
    this.syncSubmit()
    delete this.formTarget.dataset.confirmed

    if (!event.detail.success) {
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
