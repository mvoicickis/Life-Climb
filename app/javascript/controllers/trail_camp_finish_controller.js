import { Controller } from "@hotwired/stimulus"
import { clearWinSaveNotice, lockWinSubmit, showWinSaveNotice, turboSubmitOk } from "lib/battle_win_feedback"

// In-sheet finish camp card: optimistic lock, undo window, no toast.
export default class extends Controller {
  static targets = ["promptCard", "undoCard", "finishForm", "finishButton", "undoForm", "undoButton", "saveNotice"]

  static values = {
    winNotSaved: { type: String, default: "" }
  }

  connect() {
    this._undoTimer = null
  }

  disconnect() {
    window.clearTimeout(this._undoTimer)
  }

  finishClick(event) {
    if (this.element.dataset.finishInFlight === "1") {
      event.preventDefault()
      event.stopPropagation()
    }
  }

  beginFinish(event) {
    if (this.element.dataset.finishInFlight === "1") {
      event.preventDefault()
      return
    }

    this.clearSaveNotice()
    this.element.dataset.finishInFlight = "1"
    if (this.hasFinishButtonTarget) this.finishButtonTarget.disabled = true
    lockWinSubmit(this.element, true)
  }

  finishEnded(event) {
    const form = event.target
    if (!form?.classList?.contains("lp-trail-camp-finish__form")) return

    lockWinSubmit(this.element, false)
    delete this.element.dataset.finishInFlight
    if (this.hasFinishButtonTarget) this.finishButtonTarget.disabled = false

    if (!turboSubmitOk(event)) {
      const message = this.winNotSavedValue
      if (message) this.showSaveNotice(message)
      return
    }

    this.showUndoCard()
    this.markCampFinished(true)
    this.scheduleSettle()
  }

  beginUndo(event) {
    if (this.element.dataset.undoInFlight === "1") {
      event.preventDefault()
      return
    }

    this.element.dataset.undoInFlight = "1"
    window.clearTimeout(this._undoTimer)
    this._undoTimer = null
    if (this.hasUndoButtonTarget) this.undoButtonTarget.disabled = true
  }

  undoEnded(event) {
    const form = event.target
    if (!form?.classList?.contains("lp-trail-camp-finish__undo-form")) return

    delete this.element.dataset.undoInFlight
    if (this.hasUndoButtonTarget) this.undoButtonTarget.disabled = false

    if (!turboSubmitOk(event)) {
      const message = this.winNotSavedValue
      if (message) this.showSaveNotice(message)
      return
    }

    this.showPromptCard()
    this.markCampFinished(false)
  }

  markCampFinished(on) {
    const projectId = this.element.id?.replace("trail-camp-finish-", "")
    if (!projectId) return

    const camp = document.getElementById(`trail-camp-${projectId}`)
    if (!camp) return

    camp.classList.toggle("is-done", on)
    camp.classList.toggle("is-current", !on)
    let cleared = camp.querySelector(".lp-trail-camp__cleared")
    if (on && !cleared) {
      cleared = document.createElement("span")
      cleared.className = "lp-trail-camp__cleared"
      cleared.setAttribute("aria-hidden", "true")
      cleared.textContent = "✓"
      camp.querySelector(".lp-trail-camp__peg-visual")?.appendChild(cleared)
    } else if (!on) {
      cleared?.remove()
    }
  }

  showUndoCard() {
    if (this.hasPromptCardTarget) {
      this.promptCardTarget.hidden = true
      this.promptCardTarget.setAttribute("hidden", "")
    }
    if (this.hasUndoCardTarget) {
      this.undoCardTarget.hidden = false
      this.undoCardTarget.removeAttribute("hidden")
    }
    this.clearSaveNotice()
  }

  showPromptCard() {
    window.clearTimeout(this._undoTimer)
    this._undoTimer = null
    if (this.hasUndoCardTarget) {
      this.undoCardTarget.hidden = true
      this.undoCardTarget.setAttribute("hidden", "")
    }
    if (this.hasPromptCardTarget) {
      this.promptCardTarget.hidden = false
      this.promptCardTarget.removeAttribute("hidden")
    }
    this.element.classList.remove("is-hidden")
    this.element.removeAttribute("hidden")
    this.clearSaveNotice()
    this.updateSheetBadge(false)
  }

  scheduleSettle() {
    window.clearTimeout(this._undoTimer)
    this._undoTimer = window.setTimeout(() => this.settleFinished(), 5000)
  }

  settleFinished() {
    this._undoTimer = null
    this.element.classList.add("is-hidden")
    this.element.setAttribute("hidden", "")
    this.updateSheetBadge(true)
  }

  updateSheetBadge(on) {
    const sheet = this.element.closest(".lp-trail-sheet__panel")
    sheet?.classList.toggle("is-camp-finished", on)
    const badge = document.getElementById("trail-sheet-title-badge")
    if (!badge) return
    badge.hidden = !on
    badge.toggleAttribute("hidden", !on)
  }

  showSaveNotice(message) {
    if (!this.hasSaveNoticeTarget) return
    this.saveNoticeTarget.textContent = message
    this.saveNoticeTarget.hidden = false
    this.saveNoticeTarget.removeAttribute("hidden")
    this.element.classList.add("has-win-save-notice")
  }

  clearSaveNotice() {
    if (this.hasSaveNoticeTarget) {
      this.saveNoticeTarget.textContent = ""
      this.saveNoticeTarget.hidden = true
      this.saveNoticeTarget.setAttribute("hidden", "")
    }
    this.element.classList.remove("has-win-save-notice")
    clearWinSaveNotice(this.element)
  }
}
