import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    saved: Boolean,
    won: Boolean
  }

  connect() {
    const card = this.element.querySelector("#detail-card")
    if (!card) return

    if (this.savedValue) {
      card.classList.add("pop-save")
    }
    if (this.wonValue) {
      card.classList.add("glow-win")
    }
  }
}
