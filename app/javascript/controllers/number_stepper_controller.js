import { Controller } from "@hotwired/stimulus"

// Number stepper for compact settings edits (min/max clamped).
export default class extends Controller {
  static targets = ["input"]
  static values = {
    min: { type: Number, default: 1 },
    max: { type: Number, default: 20 }
  }

  decrease() {
    this.change(-1)
  }

  increase() {
    this.change(1)
  }

  change(delta) {
    const input = this.inputTarget
    const next = Math.min(this.maxValue, Math.max(this.minValue, (Number(input.value) || this.minValue) + delta))
    input.value = next
    input.dispatchEvent(new Event("input", { bubbles: true }))
    input.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
