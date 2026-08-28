import { Controller } from "@hotwired/stimulus"

// One-shot bridge: stream response dispatches page celebrate without a reload.
export default class extends Controller {
  static values = {
    celebrate: Boolean,
    apGained: Number,
    boss: Boolean,
    allClear: Boolean
  }

  connect() {
    document.dispatchEvent(
      new CustomEvent("battle-day:celebrate", {
        detail: {
          celebrate: this.celebrateValue,
          apGained: this.apGainedValue,
          boss: this.bossValue
        }
      })
    )

    const root = document.getElementById("today-dash-root")
    if (root) root.classList.toggle("is-battle-won", this.allClearValue)

    this.element.remove()
  }
}
