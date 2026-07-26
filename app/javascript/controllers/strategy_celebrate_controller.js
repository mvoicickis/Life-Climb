import { Controller } from "@hotwired/stimulus"

// Quiet SP celebration + mountain pulse on Strategy.
export default class extends Controller {
  static targets = ["spValue", "spBadge", "progressBar", "mountain"]
  static values = { gained: Number }

  connect() {
    if (this.gainedValue > 0) this.celebrate()
  }

  celebrate() {
    if (this.hasSpBadgeTarget) this.spBadgeTarget.classList.add("is-sp-pop")
    if (this.hasProgressBarTarget) this.progressBarTarget.classList.add("is-surge")
    if (this.hasMountainTarget) this.mountainTarget.classList.add("is-react")
    this.floatSp()
    this.burst()
    window.setTimeout(() => {
      this.spBadgeTarget?.classList.remove("is-sp-pop")
      this.progressBarTarget?.classList.remove("is-surge")
      this.mountainTarget?.classList.remove("is-react")
    }, 1200)
  }

  floatSp() {
    if (!this.hasSpBadgeTarget) return
    const chip = document.createElement("span")
    chip.className = "lp-strategy__sp-float"
    chip.textContent = `+${this.gainedValue} Strategy Points`
    this.spBadgeTarget.appendChild(chip)
    window.setTimeout(() => chip.remove(), 1100)
  }

  burst() {
    const root = document.createElement("div")
    root.className = "lp-strategy-confetti"
    root.setAttribute("aria-hidden", "true")
    for (let i = 0; i < 12; i += 1) {
      const bit = document.createElement("span")
      bit.style.setProperty("--x", `${(Math.random() * 140) - 70}px`)
      bit.style.setProperty("--d", `${380 + Math.random() * 650}ms`)
      root.appendChild(bit)
    }
    this.element.appendChild(root)
    window.setTimeout(() => root.remove(), 1100)
  }
}
