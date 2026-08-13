import { Controller } from "@hotwired/stimulus"

// One-question-at-a-time new-destination coach (3 steps).
export default class extends Controller {
  static targets = [ "panel", "continue", "back", "submit" ]
  static values = { step: { type: Number, default: 1 } }

  connect() {
    this.render()
  }

  reset() {
    this.stepValue = 1
    this.render()
    const input = this.currentInput()
    input?.focus()
  }

  continue(event) {
    event?.preventDefault()
    const input = this.currentInput()
    if (input && !input.checkValidity()) {
      input.reportValidity()
      return
    }
    if (this.stepValue < 3) this.stepValue += 1
    this.render()
    this.currentInput()?.focus()
  }

  back(event) {
    event?.preventDefault()
    if (this.stepValue > 1) this.stepValue -= 1
    this.render()
    this.currentInput()?.focus()
  }

  render() {
    this.panelTargets.forEach((panel) => {
      const step = Number(panel.dataset.destinationCoachStep)
      panel.hidden = step !== this.stepValue
    })
    if (this.hasBackTarget) this.backTarget.hidden = this.stepValue <= 1
    if (this.hasContinueTarget) this.continueTarget.hidden = this.stepValue >= 3
    if (this.hasSubmitTarget) this.submitTarget.hidden = this.stepValue !== 3
  }

  currentInput() {
    const panel = this.panelTargets.find((el) => Number(el.dataset.destinationCoachStep) === this.stepValue)
    return panel?.querySelector("input, textarea")
  }
}
