import { Controller } from "@hotwired/stimulus"

// Add/remove short text rows inside a Journey climb list layer.
export default class extends Controller {
  static targets = ["list", "template"]

  add(event) {
    event.preventDefault()
    if (!this.hasTemplateTarget || !this.hasListTarget) return

    const node = this.templateTarget.content.cloneNode(true)
    this.listTarget.appendChild(node)
    const input = this.listTarget.querySelector(".lp-climb-list__row:last-child input, .lp-climb-list__row:last-child textarea")
    if (input) input.focus()
  }

  remove(event) {
    event.preventDefault()
    const row = event.currentTarget.closest(".lp-climb-list__row")
    if (!row || !this.hasListTarget) return

    const rows = this.listTarget.querySelectorAll(".lp-climb-list__row")
    if (rows.length <= 1) {
      const input = row.querySelector("input, textarea")
      if (input) input.value = ""
      return
    }
    row.remove()
  }
}
