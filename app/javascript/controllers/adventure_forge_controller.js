import { Controller } from "@hotwired/stimulus"

// Staged "Forging Your Adventure" checklist, then auto-enter Today.
export default class extends Controller {
  static targets = ["step"]
  static values = {
    url: String,
    delay: { type: Number, default: 3200 }
  }

  connect() {
    this.revealSteps()
    this.timer = window.setTimeout(() => {
      window.location.assign(this.urlValue)
    }, this.delayValue)
  }

  disconnect() {
    if (this.timer) window.clearTimeout(this.timer)
  }

  revealSteps() {
    this.stepTargets.forEach((el, index) => {
      window.setTimeout(() => {
        el.classList.add("is-on")
      }, 450 * (index + 1))
    })
  }
}
