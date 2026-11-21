import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "lpTodayHabitsOpen"

// Collapsible Habits card — collapsed by default; remember open in sessionStorage.
export default class extends Controller {
  static targets = ["body"]

  connect() {
    const open = window.sessionStorage.getItem(STORAGE_KEY) === "1"
    this.element.classList.toggle("is-open", open)
    this.sync()
  }

  toggle(event) {
    event.preventDefault()
    const open = !this.element.classList.contains("is-open")
    this.element.classList.toggle("is-open", open)
    try {
      window.sessionStorage.setItem(STORAGE_KEY, open ? "1" : "0")
    } catch (_err) { /* private mode */ }
    this.sync()
  }

  sync() {
    const open = this.element.classList.contains("is-open")
    if (this.hasBodyTarget) this.bodyTarget.hidden = !open
    this.element.querySelector("[data-today-habits-trigger]")?.setAttribute("aria-expanded", open ? "true" : "false")
  }
}
