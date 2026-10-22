import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button"]
  static values = {
    showLabel: String,
    hideLabel: String
  }

  connect() {
    this.visible = false
    this.syncButton()
  }

  toggle() {
    const input = this.inputTarget
    const start = input.selectionStart
    const end = input.selectionEnd

    this.visible = !this.visible
    input.type = this.visible ? "text" : "password"

    if (start != null && end != null) {
      input.setSelectionRange(start, end)
    }

    this.syncButton()
    input.focus()
  }

  syncButton() {
    const label = this.visible ? this.hideLabelValue : this.showLabelValue
    this.buttonTarget.setAttribute("aria-label", label)
    this.buttonTarget.setAttribute("aria-pressed", this.visible ? "true" : "false")
  }
}
