import { Controller } from "@hotwired/stimulus"
import { clearWinSaveNotice, lockWinSubmit, turboSubmitOk } from "lib/battle_win_feedback"

const RESTORE_EVENT = "lp-trail-finish-card:restore"

// Stage overlay: finish camp prompt and completed-card undo window.
export default class extends Controller {
  static targets = [
    "promptCard", "undoCard", "finishForm", "finishButton", "undoForm", "undoButton", "saveNotice"
  ]

  static values = {
    qualified: { type: Boolean, default: false },
    finishedUndo: { type: Boolean, default: false },
    projectId: String,
    winNotSaved: { type: String, default: "" },
    undoLabel: { type: String, default: "" },
    reopenLabel: { type: String, default: "" }
  }

  connect() {
    this._dismissed = false
    this._undoTimer = null
    this._boundRestore = this.onRestore.bind(this)
    document.addEventListener(RESTORE_EVENT, this._boundRestore)

    if (this.finishedUndoValue) {
      this.campSheetController()?.showCampOverlays(this.projectIdValue)
      this.campSheetController()?.syncFinishCardPanelOpen(this.projectIdValue)
      this.scheduleSettle()
    } else {
      this.revealQualifiedOverlay()
      if (this.sheetOpenForThisCamp()) {
        this.campSheetController()?.syncFinishCardPanelOpen(this.projectIdValue)
      }
    }
  }

  disconnect() {
    document.removeEventListener(RESTORE_EVENT, this._boundRestore)
    if (this._undoTimer) {
      window.clearTimeout(this._undoTimer)
      this._undoTimer = null
    }
  }

  onRestore(event) {
    const projectId = event.detail?.projectId
    if (!projectId || String(projectId) !== String(this.projectIdValue)) return
    this.restoreIfQualified()
  }

  finishClick(event) {
    if (this.element.dataset.finishInFlight === "1") {
      event.preventDefault()
      event.stopPropagation()
    }
  }

  undoClick(event) {
    if (this.element.dataset.finishInFlight === "1" || this.element.dataset.undoInFlight === "1") {
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
    }
  }

  beginUndo(event) {
    if (this.element.dataset.finishInFlight === "1") {
      event.preventDefault()
      return
    }
    if (this.element.dataset.undoInFlight === "1") {
      event.preventDefault()
      return
    }

    this.clearSaveNotice()
    this.element.dataset.undoInFlight = "1"
    if (this._undoTimer) {
      window.clearTimeout(this._undoTimer)
      this._undoTimer = null
    }
    if (this.hasUndoButtonTarget) this.undoButtonTarget.disabled = true
    lockWinSubmit(this.element, true)
  }

  undoEnded(event) {
    const form = event.target
    if (!form?.classList?.contains("lp-trail-camp-finish__undo-form")) return

    lockWinSubmit(this.element, false)
    delete this.element.dataset.undoInFlight
    if (this.hasUndoButtonTarget) this.undoButtonTarget.disabled = false

    if (!turboSubmitOk(event)) {
      const message = this.winNotSavedValue
      if (message) this.showSaveNotice(message)
      this.scheduleSettle()
    }
  }

  scheduleSettle() {
    if (!this.hasUndoButtonTarget) return
    if (this._undoTimer) window.clearTimeout(this._undoTimer)
    this._undoTimer = window.setTimeout(() => this.settleFinished(), 5000)
  }

  settleFinished() {
    this._undoTimer = null
    if (!this.hasUndoButtonTarget) return
    const reopen = this.reopenLabelValue
    if (reopen) this.undoButtonTarget.textContent = reopen
  }

  addAnotherBattle(event) {
    event.preventDefault()
    this._dismissed = true
    this.element.classList.add("is-hidden")
    this.element.setAttribute("aria-hidden", "true")
    this.campSheetController()?.syncFinishCardPanelOpen(this.projectIdValue)

    const battles = document.getElementById(`trail-battles-${this.projectIdValue}`)
    const controller = this.application.getControllerForElementAndIdentifier(battles, "trail-battles")
    if (!controller) return

    controller.openComposer()
    const field = battles?.querySelector("[data-trail-battles-target='titleField']")
    field?.focus()
  }

  restoreIfQualified() {
    if (!this.qualifiedValue || !this._dismissed) return
    if (!this.element.querySelector('[data-trail-camp-finish-target="promptCard"]')) return

    this._dismissed = false
    this.element.classList.remove("is-hidden")
    this.clearSaveNotice()
    this.revealQualifiedOverlay()
  }

  revealQualifiedOverlay() {
    if (!this.qualifiedValue || this._dismissed) return
    if (!this.element.querySelector('[data-trail-camp-finish-target="promptCard"]')) return
    if (!this.sheetOpenForThisCamp()) return

    this.campSheetController()?.showCampOverlays(this.projectIdValue)
  }

  campSheetController() {
    const sheet = document.querySelector("[data-controller~='trail-camp-sheet']")
    if (!sheet) return null

    return this.application.getControllerForElementAndIdentifier(sheet, "trail-camp-sheet")
  }

  sheetOpenForThisCamp() {
    const campSheet = this.campSheetController()
    if (!campSheet?.hasSheetTarget) return false

    const sheet = campSheet.sheetTarget
    if (sheet.hidden || !sheet.classList.contains("is-open")) return false

    return String(campSheet._openCampId) === String(this.projectIdValue)
  }

  retryFinish(event) {
    event.preventDefault()
    if (!this.hasSaveNoticeTarget || this.saveNoticeTarget.hidden) return
    if (!this.hasFinishFormTarget) return
    this.clearSaveNotice()
    this.finishFormTarget.requestSubmit()
  }

  retryUndo(event) {
    event.preventDefault()
    if (!this.hasSaveNoticeTarget || this.saveNoticeTarget.hidden) return
    if (!this.hasUndoFormTarget) return
    this.clearSaveNotice()
    this.undoFormTarget.requestSubmit()
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

export { RESTORE_EVENT }
