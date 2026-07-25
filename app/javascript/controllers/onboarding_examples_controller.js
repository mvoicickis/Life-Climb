import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "field"]

  fill(event) {
    const value = event.currentTarget.dataset.value
    if (!value) return

    if (this.hasInputTarget) {
      this.inputTarget.value = value
      this.inputTarget.focus()
      return
    }

    if (this.hasFieldTarget) {
      const parts = value.split("||")
      this.fieldTargets.forEach((field, index) => {
        if (parts[index]) field.value = parts[index]
      })
    }
  }
}
