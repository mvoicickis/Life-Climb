import { Controller } from "@hotwired/stimulus"

// Journey unlock climb — scroll to focus + pulse newly unlocked layers.
export default class extends Controller {
  static targets = ["card", "clarity"]
  static values = {
    focus: String,
    unlocked: String
  }

  connect() {
    this.scrollToFocus()
    this.celebrateUnlock()
  }

  scrollToFocus() {
    const layer = this.focusValue
    if (!layer) return
    const card = this.cardTargets.find((el) => el.dataset.layer === layer)
    if (!card) return
    window.requestAnimationFrame(() => {
      card.scrollIntoView({ behavior: this.reducedMotion() ? "auto" : "smooth", block: "center" })
    })
  }

  celebrateUnlock() {
    if (this.reducedMotion()) return
    if (this.hasClarityTarget) {
      this.clarityTarget.classList.add("is-pulse")
      window.setTimeout(() => this.clarityTarget.classList.remove("is-pulse"), 900)
    }
    const unlocked = this.unlockedValue
    if (!unlocked) return
    const card = this.cardTargets.find((el) => el.dataset.layer === unlocked)
    if (!card) return
    card.classList.add("is-celebrating")
    window.setTimeout(() => card.classList.remove("is-celebrating"), 1100)
  }

  reducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }
}
