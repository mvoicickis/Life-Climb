import { Controller } from "@hotwired/stimulus"

// World-is-the-reward: battle wins change the mountain, not just numbers.
export default class extends Controller {
  static targets = ["world", "trailLit", "pct", "flag", "glass", "battleRow"]
  static values = {
    progress: Number,
    celebrate: Boolean
  }

  connect() {
    this.syncWorldState()
    if (this.celebrateValue) this.playWorldReward()
  }

  syncWorldState() {
    const progress = this.progressValue || 0
    let stage = "base"
    if (progress >= 75) stage = "summit"
    else if (progress >= 45) stage = "ridge"
    else if (progress >= 15) stage = "trail"
    this.element.dataset.stage = stage
    this.element.dataset.progress = String(progress)
    if (this.hasTrailLitTarget) {
      this.trailLitTarget.style.strokeDasharray = `${progress} 100`
    }
  }

  playWorldReward() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.syncWorldState()
      return
    }

    this.element.classList.add("is-world-reward")
    if (this.hasWorldTarget) this.worldTarget.classList.add("is-zoom")
    if (this.hasTrailLitTarget) this.trailLitTarget.classList.add("is-ignite")
    this.flagTargets.forEach((flag) => flag.classList.add("is-wave"))

    window.setTimeout(() => {
      this.element.classList.remove("is-world-reward")
      this.worldTarget?.classList.remove("is-zoom")
      this.trailLitTarget?.classList.remove("is-ignite")
      this.flagTargets.forEach((flag) => flag.classList.remove("is-wave"))
    }, 1100)
  }
}
