import { Controller } from "@hotwired/stimulus"

// Bottom ring sheet on My world — white panel, grabber, Escape + outside tap close.
export default class extends Controller {
  static targets = ["sheet", "scrim"]

  connect() {
    this._onKey = (event) => this.onKeydown(event)
    this._openRing = null
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKey)
    document.body.classList.remove("is-my-world-sheet-open")
  }

  open(event) {
    event?.preventDefault()
    event?.stopPropagation()

    const ring = event.currentTarget?.dataset?.ring
    if (!ring) return

    this.closeSheets()
    const sheet = this.sheetTargets.find((el) => el.dataset.ring === ring)
    if (!sheet) return

    this._openRing = ring
    sheet.hidden = false
    sheet.setAttribute("aria-hidden", "false")
    if (this.hasScrimTarget) {
      this.scrimTarget.hidden = false
      this.scrimTarget.setAttribute("aria-hidden", "false")
    }
    document.body.classList.add("is-my-world-sheet-open")
    document.addEventListener("keydown", this._onKey)

    requestAnimationFrame(() => {
      const focusable = sheet.querySelector(
        "button, [href], input, textarea, [tabindex]:not([tabindex='-1'])"
      )
      focusable?.focus({ preventScroll: true })
    })
  }

  close(event) {
    event?.preventDefault?.()
    event?.stopPropagation?.()
    this.teardown()
  }

  onKeydown(event) {
    if (event.key === "Escape") this.close(event)
  }

  closeSheets() {
    this.sheetTargets.forEach((sheet) => {
      sheet.hidden = true
      sheet.setAttribute("aria-hidden", "true")
    })
  }

  teardown() {
    this.closeSheets()
    if (this.hasScrimTarget) {
      this.scrimTarget.hidden = true
      this.scrimTarget.setAttribute("aria-hidden", "true")
    }
    document.removeEventListener("keydown", this._onKey)
    document.body.classList.remove("is-my-world-sheet-open")
    this._openRing = null
  }
}
