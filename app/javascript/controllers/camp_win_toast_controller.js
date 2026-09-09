import { Controller } from "@hotwired/stimulus"

// Auto-dismiss camp sheet win undo toast after 5 seconds.
export default class extends Controller {
  connect() {
    this._timer = window.setTimeout(() => this.element.remove(), 5000)
  }

  disconnect() {
    if (this._timer) window.clearTimeout(this._timer)
  }
}
