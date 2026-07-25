import { Controller } from "@hotwired/stimulus"

// Tap an example chip to fill the nearest field(s).
export default class extends Controller {
  static targets = ["input", "field"]

  fill(event) {
    event.preventDefault()
    const value = event.currentTarget.dataset.value
    if (!value) return

    if (this.hasInputTarget) {
      this.inputTarget.value = value
      this.inputTarget.focus()
      return
    }

    // Multi-field steps (steps / today actions): fill blank fields in order
    const values = value.split("||").map((v) => v.trim()).filter(Boolean)
    this.fieldTargets.forEach((field, index) => {
      if (values[index]) field.value = values[index]
    })
    this.fieldTargets[0]?.focus()
  }
}
