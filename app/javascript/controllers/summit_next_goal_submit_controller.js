import { Controller } from "@hotwired/stimulus"

// Camps step — JSON submit with in-flight guard and tap-to-retry copy.
export default class extends Controller {
  static targets = [ "form", "submit", "error" ]

  static values = {
    notSaved: String
  }

  connect() {
    this.inFlight = false
  }

  async submit(event) {
    event.preventDefault()
    if (this.inFlight) return

    const form = this.hasFormTarget ? this.formTarget : event.target
    if (!form || form.method?.toLowerCase() !== "post" && form.getAttribute("method")?.toLowerCase() !== "post") {
      form.requestSubmit?.()
      return
    }

    this.inFlight = true
    this.clearError()
    if (this.hasSubmitTarget) this.submitTarget.disabled = true

    const token = document.querySelector("meta[name='csrf-token']")?.content
    const body = new FormData(form)

    try {
      const response = await fetch(form.action, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": token || ""
        },
        body
      })

      const payload = await response.json().catch(() => ({}))
      if (response.ok && payload.redirect_to) {
        window.location.assign(payload.redirect_to)
        return
      }

      this.showError(payload.error)
    } catch (_error) {
      this.showError()
    } finally {
      this.inFlight = false
      if (this.hasSubmitTarget) this.submitTarget.disabled = false
    }
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message || this.notSavedValue || "Not saved. Tap to try again."
    this.errorTarget.hidden = false
  }

  clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.hidden = true
    this.errorTarget.textContent = ""
  }
}
