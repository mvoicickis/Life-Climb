import { Controller } from "@hotwired/stimulus"

// Inline rename for Strategy Goal/Plan/Project/Battle titles.
export default class extends Controller {
  static targets = ["display", "form", "input", "label"]
  static values = { editing: { type: Boolean, default: false } }

  edit(event) {
    event?.preventDefault()
    this.editingValue = true
    this.displayTarget.hidden = true
    this.formTarget.hidden = false
    if (this.hasInputTarget) {
      this.inputTarget.focus()
      this.inputTarget.select()
    }
  }

  cancel(event) {
    event?.preventDefault()
    this.editingValue = false
    this.formTarget.hidden = true
    this.displayTarget.hidden = false
    if (this.hasInputTarget && this.hasLabelTarget) {
      this.inputTarget.value = this.labelTarget.textContent.trim()
    }
  }

  onKeydown(event) {
    if (event.key === "Escape") this.cancel(event)
  }
}
