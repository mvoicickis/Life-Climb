import { Controller } from "@hotwired/stimulus"

// Tracker state chips: highlight on tap and auto-save the Habit form.
export default class extends Controller {
  static targets = ["choice"]

  connect() {
    this.syncActive()
  }

  select(event) {
    if (event.target.type !== "radio") return

    this.syncActive()
    if (typeof this.element.requestSubmit === "function") {
      this.element.requestSubmit()
    } else {
      this.element.submit()
    }
  }

  syncActive() {
    this.choiceTargets.forEach((label) => {
      const input = label.querySelector('input[type="radio"]')
      label.classList.toggle("is-active", Boolean(input?.checked))
    })
  }
}
