import { Controller } from "@hotwired/stimulus"

// Toggle Battles / Habits inline reveals on the commitment_gap panel.
export default class extends Controller {
  static targets = ["battleReveal", "habitReveal", "battlePlus", "habitPlus", "quantityUnit"]
  static values = { open: String }

  connect() {
    this.applyOpen(this.openValue)
    this.syncQuantityUnit()
  }

  toggleBattle(event) {
    event.preventDefault()
    this.toggle("battle")
  }

  toggleHabit(event) {
    event.preventDefault()
    this.toggle("habit")
  }

  toggleQuantity() {
    this.syncQuantityUnit()
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
    this.stylePlus(this.hasBattlePlusTarget ? this.battlePlusTarget : null, name === "battle", "battle")
    this.stylePlus(this.hasHabitPlusTarget ? this.habitPlusTarget : null, name === "habit", "habit")
  }

  stylePlus(button, isOpen, _kind) {
    if (!button) return
    button.classList.toggle("is-open", isOpen)
    button.setAttribute("aria-expanded", isOpen ? "true" : "false")
    button.textContent = isOpen ? "×" : "+"
    const addLabel = button.dataset.addLabel
    const closeLabel = button.dataset.closeLabel
    button.setAttribute("aria-label", isOpen ? (closeLabel || "Close") : (addLabel || "Add"))
  }

  syncQuantityUnit() {
    if (!this.hasQuantityUnitTarget) return
    const checkbox = this.element.querySelector('[data-commitment-gap-quantity]')
    const on = checkbox ? checkbox.checked : false
    this.quantityUnitTarget.hidden = !on
    const input = this.quantityUnitTarget.querySelector("input")
    if (input) input.required = on
  }
}
