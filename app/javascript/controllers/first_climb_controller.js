import { Controller } from "@hotwired/stimulus"

// Prevents double-tap on "Start my climb" while the (non-Turbo) POST is in flight.
// Example chips fill the matching input so the player can edit before submit.
export default class extends Controller {
  static targets = [ "submit", "planInput", "actionInput" ]

  disable() {
    const button = this.hasSubmitTarget
      ? this.submitTarget
      : this.element.querySelector('[type="submit"]')
    if (!button || button.disabled) return

    button.disabled = true
    button.setAttribute("aria-busy", "true")
  }

  fill({ params }) {
    const value = (params.value || "").toString()
    if (!value) return

    const input = params.field === "action"
      ? (this.hasActionInputTarget ? this.actionInputTarget : this.element.querySelector("#first-climb-action"))
      : (this.hasPlanInputTarget ? this.planInputTarget : this.element.querySelector("#first-climb-plan"))

    if (!input) return
    input.value = value
    input.dispatchEvent(new Event("input", { bubbles: true }))
    input.focus()
  }
}
