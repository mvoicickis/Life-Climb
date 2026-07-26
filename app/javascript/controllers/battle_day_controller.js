import { Controller } from "@hotwired/stimulus"

// Subtle juice for Complete Battle — confetti, CTA pulse, reward nudge.
export default class extends Controller {
  static targets = ["completeBtn", "reward", "goalPct", "goalBar", "item", "lpTotal"]
  static values = { closer: Number }

  celebrate() {
    this.element.classList.add("is-celebrating")
    this.burst()
    this.nudgeReward()
    this.nudgeGoal()
    window.setTimeout(() => this.element.classList.remove("is-celebrating"), 1400)
  }

  nudgeReward() {
    if (!this.hasRewardTarget) return
    this.rewardTarget.classList.add("is-pulse")
    window.setTimeout(() => this.rewardTarget.classList.remove("is-pulse"), 900)
  }

  nudgeGoal() {
    if (!this.hasGoalBarTarget) return
    this.goalBarTarget.classList.add("is-glow")
    if (this.hasGoalPctTarget) this.goalPctTarget.classList.add("is-glow")
    window.setTimeout(() => {
      this.goalBarTarget.classList.remove("is-glow")
      this.goalPctTarget?.classList.remove("is-glow")
    }, 900)
  }

  burst() {
    const root = document.createElement("div")
    root.className = "lp-dash-confetti"
    root.setAttribute("aria-hidden", "true")
    for (let i = 0; i < 22; i += 1) {
      const bit = document.createElement("span")
      bit.style.setProperty("--x", `${(Math.random() * 180) - 90}px`)
      bit.style.setProperty("--d", `${420 + Math.random() * 780}ms`)
      bit.style.setProperty("--h", `${85 + Math.random() * 45}`)
      root.appendChild(bit)
    }
    this.element.appendChild(root)
    window.setTimeout(() => root.remove(), 1300)
  }
}
