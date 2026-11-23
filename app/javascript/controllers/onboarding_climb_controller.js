import { Controller } from "@hotwired/stimulus"

// Frame 5 climb animation — summit, tents, tap to skip, reduced motion shows Next immediately.
export default class extends Controller {
  static targets = ["summit", "camp", "campChip", "next", "stage", "root"]
  static values = {
    goal: String,
    camps: Array
  }

  connect() {
    this.timers = []
    this.reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.play()
  }

  disconnect() {
    this.clearTimers()
  }

  play() {
    this.clearTimers()
    this.resetNodes()
    const names = (this.campsValue || []).slice(0, 3)

    if (this.reduceMotion) {
      this.summitTarget.classList.add("is-in")
      this.campTargets.forEach((slot, index) => {
        const name = names[index]
        if (!name) return
        const chip = this.campChipTargets[index]
        if (chip) chip.textContent = name
        slot.classList.add("is-in")
      })
      this.showNext()
      return
    }

    this.timers.push(window.setTimeout(() => {
      this.summitTarget.classList.add("is-in")
    }, 280))

    names.forEach((name, index) => {
      this.timers.push(window.setTimeout(() => {
        const slot = this.campTargets[index]
        if (!slot) return
        const chip = this.campChipTargets[index]
        if (chip) chip.textContent = name
        slot.classList.add("is-in")
      }, 700 + index * 400))
    })

    const doneAt = 700 + Math.max(names.length, 1) * 400 + 200
    this.timers.push(window.setTimeout(() => this.showNext(), doneAt))
  }

  skipToEnd(event) {
    if (event.target.closest("[data-onboarding-climb-next]")) return
    if (this.nextTarget.classList.contains("is-shown")) return

    event.preventDefault()
    this.clearTimers()
    const names = (this.campsValue || []).slice(0, 3)
    this.summitTarget.classList.add("is-in")
    this.campTargets.forEach((node, index) => {
      const name = names[index]
      if (!name) return
      const chip = this.campChipTargets[index]
      if (chip) chip.textContent = name
      node.classList.add("is-in")
    })
    this.showNext()
  }

  clearTimers() {
    this.timers.forEach((id) => window.clearTimeout(id))
    this.timers = []
  }

  resetNodes() {
    this.summitTarget.classList.remove("is-in")
    this.nextTarget.classList.remove("is-shown")
    this.campTargets.forEach((node) => node.classList.remove("is-in"))
    this.campChipTargets.forEach((chip) => { chip.textContent = "" })
  }

  showNext() {
    this.nextTarget.classList.add("is-shown")
  }
}