import { Controller } from "@hotwired/stimulus"

// Mountain dock: tick wins must not open the camp sheet behind the card.
export default class extends Controller {
  stopBubble(event) {
    event.stopPropagation()
  }

  keydown(event) {
    if (event.key !== "Enter" && event.key !== " ") return
    if (event.target.closest(".lp-trail-battles__tick-form")) return

    event.preventDefault()
    event.currentTarget.click()
  }
}
