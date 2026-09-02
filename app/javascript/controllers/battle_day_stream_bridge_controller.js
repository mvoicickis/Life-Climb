import { Controller } from "@hotwired/stimulus"

// One-shot bridge: stream response triggers battle-day win without a reload.
export default class extends Controller {
  static values = {
    celebrate: Boolean,
    apGained: Number,
    boss: Boolean,
    allClear: Boolean,
    winNumber: Number,
    pushOfferEligible: Boolean
  }

  connect() {
    const root = document.getElementById("today-dash-root")
    const detail = {
      celebrate: this.celebrateValue,
      apGained: this.apGainedValue,
      boss: this.bossValue,
      winNumber: this.winNumberValue,
      pushOfferEligible: this.pushOfferEligibleValue
    }

    const battleDay = root && this.application.getControllerForElementAndIdentifier(root, "battle-day")
    if (battleDay) {
      battleDay.triggerWin(detail)
    } else {
      document.dispatchEvent(new CustomEvent("battle-day:celebrate", { detail }))
    }

    if (root) root.classList.toggle("is-battle-won", this.allClearValue)

    this.element.remove()
  }
}
