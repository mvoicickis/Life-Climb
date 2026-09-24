import { Controller } from "@hotwired/stimulus"
import { clearWinSaveNotice, lockWinSubmit, turboSubmitOk } from "lib/battle_win_feedback"

const RESTORE_EVENT = "lp-trail-finish-card:restore"

// Stage overlay: finish camp prompt for one-shot camps with all battles won.
export default class extends Controller {
  static targets = ["finishForm", "finishButton", "saveNotice"]

  static values = {
    qualified: { type: Boolean, default: false },
    projectId: String,
    winNotSaved: { type: String, default: "" }
  }

  connect() {
    this._dismissed = false
    this._boundRestore = this.onRestore.bind(this)
    document.addEventListener(RESTORE_EVENT, this._boundRestore)
  }

  disconnect() {
    document.removeEventListener(RESTORE_EVENT, this._boundRestore)
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

  addAnotherBattle(event) {
    event.preventDefault()
    this._dismissed = true
    this.element.classList.add("is-hidden")
    this.element.setAttribute("aria-hidden", "true")

    const battles = document.getElementById(`trail-battles-${this.projectIdValue}`)
    const controller = this.application.getControllerForElementAndIdentifier(battles, "trail-battles")
    if (!controller) return

    controller.openComposer()
    const field = battles?.querySelector("[data-trail-battles-target='titleField']")
    field?.focus()
  }

  restoreIfQualified() {
    if (!this.qualifiedValue || !this._dismissed) return
    if (!this.element.querySelector(".lp-trail-camp-finish__card")) return

    this._dismissed = false
    this.element.classList.remove("is-hidden")
    this.clearSaveNotice()

    const sheet = document.querySelector("[data-controller~='trail-camp-sheet']")
    const campSheet = sheet
      ? this.application.getControllerForElementAndIdentifier(sheet, "trail-camp-sheet")
      : null
    campSheet?.showCampOverlays(this.projectIdValue)
  }

  retryFinish(event) {
    event.preventDefault()
    if (!this.hasSaveNoticeTarget || this.saveNoticeTarget.hidden) return
    this.clearSaveNotice()
    this.finishFormTarget?.requestSubmit()
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
