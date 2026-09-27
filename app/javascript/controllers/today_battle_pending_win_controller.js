import { Controller } from "@hotwired/stimulus"

const DEFAULT_UNDO_MS = 4000
const SLIDE_MS = 480

export default class extends Controller {
  static targets = [ "undo" ]
  static values = { undoMs: { type: Number, default: DEFAULT_UNDO_MS } }

  connect() {
    if (!this.element.classList.contains("is-pending-won")) return

    if (this.hasUndoTarget) this.undoTarget.hidden = false
    this.slideTimer = window.setTimeout(() => this.slideToWon(), this.undoMsValue)
  }

  disconnect() {
    window.clearTimeout(this.slideTimer)
  }

  undo(event) {
    event.preventDefault()
    event.stopPropagation()
    window.clearTimeout(this.slideTimer)
    const form = this.element.querySelector("form.lp-today-v2-row__check-form")
    if (typeof form?.requestSubmit === "function") {
      form.requestSubmit()
    } else {
      form?.submit()
    }
  }

  slideToWon() {
    const row = this.element
    const list = document.getElementById("today-battlefield-won-list")
    const shell = document.getElementById("today-battlefield-won-shell")
    if (!list || !shell) return

    shell.hidden = false
    if (this.hasUndoTarget) this.undoTarget.hidden = true

    const listRect = list.getBoundingClientRect()
    const rowRect = row.getBoundingClientRect()
    const dy = listRect.top - rowRect.top + 6

    row.classList.add("is-sliding")
    row.style.transform = `translateY(${dy}px)`
    row.style.opacity = "0.5"

    window.setTimeout(() => {
      row.classList.remove("is-sliding", "is-pending-won")
      row.classList.add("is-won-row")
      row.style.transform = ""
      row.style.opacity = ""
      list.prepend(row)
    }, SLIDE_MS)
  }
}
