import { Controller } from "@hotwired/stimulus"

// Streak moment overlay on Today — number roll + week ticks, then dismiss.
export default class extends Controller {
  connect() {
    this.element.classList.add("is-animating")
    this._doneTimer = window.setTimeout(() => {
      this.element.classList.remove("is-animating")
      this.element.classList.add("is-done")
    }, 1600)
  }

  disconnect() {
    window.clearTimeout(this._doneTimer)
  }

  dismiss(event) {
    event?.preventDefault?.()
    this.element.remove()
  }
}
