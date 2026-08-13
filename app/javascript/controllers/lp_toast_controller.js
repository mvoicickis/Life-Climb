import { Controller } from "@hotwired/stimulus"

// Reusable auto-dismiss toast (Today habit undo, etc.).
export default class extends Controller {
  static values = {
    duration: { type: Number, default: 3200 }
  }

  connect() {
    requestAnimationFrame(() => this.element.classList.add("is-show"))
    this.timer = window.setTimeout(() => this.dismiss(), this.durationValue)
  }

  disconnect() {
    if (this.timer) window.clearTimeout(this.timer)
  }

  dismiss() {
    this.element.classList.remove("is-show")
    window.setTimeout(() => this.element.remove(), 280)
  }
}
