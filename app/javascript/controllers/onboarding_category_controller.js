import { Controller } from "@hotwired/stimulus"

// Tap a category card → brief highlight/check → advance to the mountain step.
export default class extends Controller {
  static targets = [ "card" ]
  static values = { delay: { type: Number, default: 340 } }

  pick(event) {
    if (this.submitting) return
    if (event.type === "keydown") event.preventDefault()

    const card = event.currentTarget
    const input = card.querySelector('input[type="radio"]')
    if (!input) return

    input.checked = true
    this.submitting = true

    this.cardTargets.forEach((other) => {
      other.classList.toggle("is-picked", other === card)
      other.classList.toggle("is-dimmed", other !== card)
      other.setAttribute("aria-disabled", other === card ? "false" : "true")
    })

    card.classList.add("is-confirming")

    window.setTimeout(() => {
      const form = this.element
      if (typeof form.requestSubmit === "function") {
        form.requestSubmit()
      } else {
        form.submit()
      }
    }, this.delayValue)
  }
}
