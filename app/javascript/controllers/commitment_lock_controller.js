import { Controller } from "@hotwired/stimulus"

// Visible "locked" feedback when tapping ineligible Medium/Hard commitment cards.
// Radios stay disabled — this only nudges the already-rendered reason text.
export default class extends Controller {
  nudge(event) {
    const card = event.target.closest(".lp-adventure__commitment-card.is-disabled")
    if (!card || !this.element.contains(card)) return

    event.preventDefault()
    card.classList.remove("is-nudge")
    // Force reflow so re-tapping restarts the animation.
    void card.offsetWidth
    card.classList.add("is-nudge")

    clearTimeout(this.nudgeTimer)
    this.nudgeTimer = setTimeout(() => card.classList.remove("is-nudge"), 400)
  }

  disconnect() {
    clearTimeout(this.nudgeTimer)
  }
}
