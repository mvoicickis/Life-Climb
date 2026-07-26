import { Controller } from "@hotwired/stimulus"

// Pulse SP badge and briefly celebrate planning awards on Strategy.
export default class extends Controller {
  static targets = ["spValue", "spBadge", "progressBar"]
  static values = { gained: Number }

  connect() {
    if (this.gainedValue > 0) this.celebrate()
  }

  fillExample(event) {
    const title = event.currentTarget.dataset.title
    const input = this.element.querySelector("#next-up-title")
    if (input && title) {
      input.value = title
      input.focus()
    }
  }

  celebrate() {
    if (this.hasSpBadgeTarget) this.spBadgeTarget.classList.add("is-sp-pop")
    if (this.hasProgressBarTarget) this.progressBarTarget.classList.add("is-surge")
    this.burst()
    window.setTimeout(() => {
      this.spBadgeTarget?.classList.remove("is-sp-pop")
      this.progressBarTarget?.classList.remove("is-surge")
    }, 1200)
  }

  burst() {
    const root = document.createElement("div")
    root.className = "lp-strategy-confetti"
    root.setAttribute("aria-hidden", "true")
    for (let i = 0; i < 16; i += 1) {
      const bit = document.createElement("span")
      bit.style.setProperty("--x", `${(Math.random() * 160) - 80}px`)
      bit.style.setProperty("--d", `${400 + Math.random() * 700}ms`)
      root.appendChild(bit)
    }
    this.element.appendChild(root)
    window.setTimeout(() => root.remove(), 1200)
  }
}
