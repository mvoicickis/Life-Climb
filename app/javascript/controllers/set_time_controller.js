import { Controller } from "@hotwired/stimulus"

// Reveals inline start/end time inputs on an Unscheduled Today card.
export default class extends Controller {
  static targets = ["panel", "trigger"]

  open(event) {
    event?.preventDefault?.()
    if (!this.hasPanelTarget) return
    this.panelTarget.hidden = false
    if (this.hasTriggerTarget) this.triggerTarget.hidden = true
  }

  close(event) {
    event?.preventDefault?.()
    if (!this.hasPanelTarget) return
    this.panelTarget.hidden = true
    if (this.hasTriggerTarget) this.triggerTarget.hidden = false
  }
}
