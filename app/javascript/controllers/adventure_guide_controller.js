import { Controller } from "@hotwired/stimulus"

// Stepped "How the Game Works" demo: stack → win battle → persistence → map.
export default class extends Controller {
  static targets = ["panel", "bar", "pct", "wonNote", "winButton", "battleOne"]

  connect() {
    this.index = 0
    this.showPanel(0)
  }

  next(event) {
    event?.preventDefault()
    this.showPanel(Math.min(this.index + 1, this.panelTargets.length - 1))
  }

  winBattle(event) {
    event?.preventDefault()
    if (this.winButtonTarget.disabled) return

    this.winButtonTarget.disabled = true
    this.winButtonTarget.classList.add("is-won")
    if (this.hasBattleOneTarget) this.battleOneTarget.classList.add("is-done")
    if (this.hasWonNoteTarget) this.wonNoteTarget.hidden = false

    this.animateProgress(40, 65)

    window.setTimeout(() => this.showPanel(2), 900)
  }

  showPanel(index) {
    this.index = index
    this.panelTargets.forEach((panel, i) => {
      panel.classList.toggle("is-on", i === index)
      panel.hidden = i !== index
    })
  }

  animateProgress(from, to) {
    if (!this.hasBarTarget || !this.hasPctTarget) return

    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    if (reduced) {
      this.barTarget.style.width = `${to}%`
      this.pctTarget.textContent = `${to}%`
      return
    }

    this.barTarget.style.width = `${from}%`
    this.pctTarget.textContent = `${from}%`
    window.requestAnimationFrame(() => {
      this.barTarget.style.width = `${to}%`
      this.pctTarget.textContent = `${to}%`
    })
  }
}
