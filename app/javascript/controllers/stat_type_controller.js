import { Controller } from "@hotwired/stimulus"

// Show Growth or Standard fields based on selected stat type.
export default class extends Controller {
  static targets = ["growthFields", "standardFields"]
  static values = { type: String }

  connect() {
    this.refresh()
  }

  change(event) {
    this.typeValue = event.target.value
    this.refresh()
  }

  refresh() {
    const growth = this.typeValue === "growth"
    this.growthFieldsTargets.forEach((el) => { el.hidden = !growth })
    this.standardFieldsTargets.forEach((el) => { el.hidden = growth })
  }
}
