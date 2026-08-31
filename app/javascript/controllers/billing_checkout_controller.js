import { Controller } from "@hotwired/stimulus"

// POSTs to billing checkout/portal endpoints and redirects to Stripe.
export default class extends Controller {
  static targets = [ "button", "error" ]
  static values = {
    checkoutUrl: String,
    portalUrl: String
  }

  async checkout(event) {
    const interval = event.currentTarget.dataset.interval
    if (!interval) return

    await this.redirectTo(this.checkoutUrlValue, { interval })
  }

  async portal() {
    await this.redirectTo(this.portalUrlValue, {})
  }

  async redirectTo(url, params) {
    if (!url) return

    this.clearError()
    this.setLoading(true)

    try {
      const token = document.querySelector("meta[name='csrf-token']")?.content
      const body = new URLSearchParams(params)
      body.set("authenticity_token", token || "")

      const response = await fetch(url, {
        method: "POST",
        headers: {
          "X-CSRF-Token": token || "",
          Accept: "application/json"
        },
        body,
        credentials: "same-origin"
      })

      const payload = await response.json().catch(() => ({}))
      if (!response.ok || !payload.url) {
        this.showError(this.errorMessage(payload.error))
        return
      }

      window.location.assign(payload.url)
    } catch (_error) {
      this.showError(this.errorMessage("network"))
    } finally {
      this.setLoading(false)
    }
  }

  errorMessage(code) {
    const messages = {
      invalid_interval: "Something went wrong. Try again.",
      price_not_found: "This plan is not available right now.",
      missing_customer: "Billing is not set up yet.",
      stripe_error: "Something went wrong. Try again.",
      network: "Something went wrong. Try again."
    }
    return messages[code] || messages.network
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
  }

  clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ""
    this.errorTarget.hidden = true
  }

  setLoading(loading) {
    this.buttonTargets.forEach((button) => {
      button.disabled = loading
      button.setAttribute("aria-busy", loading ? "true" : "false")
    })
  }
}
