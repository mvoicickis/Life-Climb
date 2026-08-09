import { Controller } from "@hotwired/stimulus"

// Toggle Battles / Habits inline reveals on the commitment_gap panel.
export default class extends Controller {
  static targets = ["battleReveal", "habitReveal"]
  static values = { open: String }

  connect() {
    this.applyOpen(this.openValue)
  }

  toggleBattle(event) {
    event.preventDefault()
    this.toggle("battle")
  }

  toggleHabit(event) {
    event.preventDefault()
    this.toggle("habit")
  }

  toggle(name) {
    const next = this.openValue === name ? "" : name
    this.openValue = next
    this.applyOpen(next)
  }

  applyOpen(name) {
    if (this.hasBattleRevealTarget) {
      this.battleRevealTarget.hidden = name !== "battle"
    }
    if (this.hasHabitRevealTarget) {
      this.habitRevealTarget.hidden = name !== "habit"
    }
  }
}
