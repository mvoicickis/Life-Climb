import { Controller } from "@hotwired/stimulus"

// Reveals the inline "Add step" title field on a Today battle card.
export default class extends Controller {
  static targets = ["panel", "trigger", "title"]

  open(event) {
    event?.preventDefault?.()
    if (!this.hasPanelTarget) return
    this.panelTarget.hidden = false
    if (this.hasTriggerTarget) this.triggerTarget.hidden = true
    if (this.hasTitleTarget) this.titleTarget.focus()
  }

  close(event) {
    event?.preventDefault?.()
    if (!this.hasPanelTarget) return
    this.panelTarget.hidden = true
    if (this.hasTriggerTarget) this.triggerTarget.hidden = false
  }
}
