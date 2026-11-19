import { Controller } from "@hotwired/stimulus"
import { burst, sound } from "lib/lp_feedback"

// SP / AP juice + camp nudge + optional soft chime on Mountain.
export default class extends Controller {
  static targets = ["spValue", "spBadge", "progressBar", "mountain", "camp"]
  static values = {
    gained: Number,
    apGained: Number,
    boss: Boolean
  }

  connect() {
    if (this.gainedValue > 0 || this.apGainedValue > 0) this.celebrate()
  }

  celebrate() {
    if (this.hasSpBadgeTarget && this.gainedValue > 0) this.spBadgeTarget.classList.add("is-sp-pop")
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.classList.add("is-surge", "is-bounce")
    }
    if (this.hasMountainTarget) {
      this.mountainTarget.classList.add("is-react")
      if (this.bossValue) this.mountainTarget.classList.add("is-boss")
    }
    if (this.hasCampTarget) this.campTarget.classList.add("is-nudge")
    this.floatPoints()
    burst(this.element, { density: "strategy", boss: this.bossValue })
    sound(this.bossValue ? "strategy_boss" : "strategy", { boss: this.bossValue })
    window.setTimeout(() => {
      this.spBadgeTarget?.classList.remove("is-sp-pop")
      this.progressBarTarget?.classList.remove("is-surge", "is-bounce")
      this.mountainTarget?.classList.remove("is-react", "is-boss")
      this.campTarget?.classList.remove("is-nudge")
    }, this.bossValue ? 1800 : 1200)
  }

  floatPoints() {
    if (this.gainedValue > 0 && this.hasSpBadgeTarget) {
      const chip = document.createElement("span")
      chip.className = "lp-strategy__sp-float"
      chip.textContent = `+${this.gainedValue} ${this.spLabel()}`
      this.spBadgeTarget.appendChild(chip)
      window.setTimeout(() => chip.remove(), 1100)
    }
    if (this.apGainedValue > 0) {
      const host = this.hasMountainTarget ? this.mountainTarget : this.element
      const chip = document.createElement("span")
      chip.className = "lp-strategy__ap-float lp-rpg-xp-float"
      chip.textContent = `+${this.apGainedValue} XP`
      host.appendChild(chip)
      window.setTimeout(() => chip.remove(), 1200)
    }
  }

  spLabel() {
    return "planning"
  }
}
