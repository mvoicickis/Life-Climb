import { Controller } from "@hotwired/stimulus"

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
    this.burst()
    this.chime()
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
      chip.className = "lp-strategy__ap-float"
      chip.textContent = `+${this.apGainedValue} AP`
      host.appendChild(chip)
      window.setTimeout(() => chip.remove(), 1200)
    }
  }

  spLabel() {
    return "planning"
  }

  burst() {
    const root = document.createElement("div")
    root.className = this.bossValue ? "lp-strategy-confetti is-boss" : "lp-strategy-confetti"
    root.setAttribute("aria-hidden", "true")
    const count = this.bossValue ? 22 : 12
    for (let i = 0; i < count; i += 1) {
      const bit = document.createElement("span")
      bit.style.setProperty("--x", `${(Math.random() * 160) - 80}px`)
      bit.style.setProperty("--d", `${380 + Math.random() * 650}ms`)
      root.appendChild(bit)
    }
    this.element.appendChild(root)
    window.setTimeout(() => root.remove(), 1200)
  }

  chime() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    try {
      const Ctx = window.AudioContext || window.webkitAudioContext
      if (!Ctx) return
      const ctx = new Ctx()
      const osc = ctx.createOscillator()
      const gain = ctx.createGain()
      osc.type = "sine"
      osc.frequency.value = this.bossValue ? 523.25 : 392
      gain.gain.value = 0.0001
      osc.connect(gain)
      gain.connect(ctx.destination)
      const now = ctx.currentTime
      gain.gain.exponentialRampToValueAtTime(0.05, now + 0.02)
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.28)
      osc.start(now)
      osc.stop(now + 0.3)
      window.setTimeout(() => ctx.close(), 400)
    } catch (_err) {
      // Audio is optional juice — ignore blocked autoplay.
    }
  }
}
