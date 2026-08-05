import { Controller } from "@hotwired/stimulus"

// Reveal the optional finish-line date picker on the deadline step.
export default class extends Controller {
  static targets = [ "picker", "toggle" ]

  show(event) {
    event.preventDefault()
    if (!this.hasPickerTarget) return

    this.pickerTarget.hidden = false
    if (this.hasToggleTarget) this.toggleTarget.hidden = true

    const input = this.pickerTarget.querySelector('input[type="date"]')
    if (input) input.focus()
  }
}
