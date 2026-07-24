import { Controller } from "@hotwired/stimulus"

// Toggle "Enable a target" and show the right evaluation fields.
export default class extends Controller {
  static targets = ["enabled", "targetPanel", "growthFields", "standardFields", "typeInput"]
  static values = {
    type: { type: String, default: "growth" },
    enabled: { type: Boolean, default: false }
  }

  connect() {
    this.refresh()
  }

  toggleEnabled(event) {
    this.enabledValue = event.target.checked
    if (!this.enabledValue) {
      this.typeValue = "growth"
      this.typeInputTargets.forEach((input) => {
        if (input.value === "growth") input.checked = true
      })
    }
    this.refresh()
  }

  changeType(event) {
    this.typeValue = event.target.value
    this.refresh()
  }

  refresh() {
    const enabled = this.enabledValue
    this.targetPanelTargets.forEach((el) => { el.hidden = !enabled })

    const growth = this.typeValue !== "standard"
    this.growthFieldsTargets.forEach((el) => { el.hidden = !(enabled && growth) })
    this.standardFieldsTargets.forEach((el) => { el.hidden = !(enabled && !growth) })
  }
}
