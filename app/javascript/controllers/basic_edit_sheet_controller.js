import { Controller } from "@hotwired/stimulus"
import { applyTurboStreamFromResponse } from "lib/apply_turbo_stream"

const MAX_NAME_LINES = 3

export default class extends Controller {
  static targets = [
    "nameInput",
    "quickInput",
    "unitInput",
    "saveNotice",
    "doneBtn",
    "deleteSlot",
    "deleteLink",
    "confirmTemplate"
  ]

  static values = {
    updateUrl: String,
    destroyUrl: String,
    returnTo: String,
    habitId: Number,
    countable: Boolean,
    winNotSaved: String,
    initialName: String,
    initialUnit: String,
    initialQuick: String,
    todayRowId: String,
    trailRowId: String,
    deleteBasic: String,
    lifeJourneyId: Number,
    goalId: Number,
    planId: Number
  }

  connect() {
    this.inFlight = false
    this.confirmOpen = false
    this._onViewport = () => this.syncKeyboardInset()
    this.resizeName()
    this.bindMenuOpen()
  }

  disconnect() {
    this.unbindMenuOpen()
    this.resetKeyboardInset()
  }

  bindMenuOpen() {
    this.details = this.element.closest("details")
    if (!this.details) return
    this._onToggle = () => {
      if (this.details.open) {
        window.visualViewport?.addEventListener("resize", this._onViewport)
        this.syncKeyboardInset()
      } else {
        window.visualViewport?.removeEventListener("resize", this._onViewport)
        this.resetKeyboardInset()
        this.restoreDeleteLink()
      }
    }
    this.details.addEventListener("toggle", this._onToggle)
  }

  unbindMenuOpen() {
    if (this.details && this._onToggle) {
      this.details.removeEventListener("toggle", this._onToggle)
    }
    window.visualViewport?.removeEventListener("resize", this._onViewport)
  }

  // Camp sheet uses offsetTop in trail_camp_sheet_controller; Edit Basic uses height gap only.
  syncKeyboardInset() {
    if (!this.details?.open) return
    const viewport = window.visualViewport
    let inset = "0px"
    if (viewport) {
      const gap = Math.max(0, window.innerHeight - viewport.height)
      if (gap > 120) inset = `${gap}px`
    }
    this.element.style.setProperty("--lp-basic-edit-keyboard-inset", inset)
  }

  resetKeyboardInset() {
    this.element.style.setProperty("--lp-basic-edit-keyboard-inset", "0px")
  }

  resizeName() {
    if (!this.hasNameInputTarget) return
    const el = this.nameInputTarget
    el.style.height = "auto"
    const lineHeight = parseFloat(getComputedStyle(el).lineHeight) || 22
    const maxHeight = lineHeight * MAX_NAME_LINES
    el.style.height = `${Math.min(el.scrollHeight, maxHeight)}px`
    el.style.overflowY = el.scrollHeight > maxHeight ? "auto" : "hidden"
  }

  fieldKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.done(event)
    } else if (event.key === "Escape") {
      event.preventDefault()
      if (this.confirmOpen) this.keepDelete(event)
      else this.closeMenu()
    }
  }

  done(event) {
    event?.preventDefault?.()
    if (this.inFlight || this.confirmOpen) return
    this.hideNotice()
    if (!this.validateFields()) return
    if (!this.hasChanges()) {
      this.closeMenu()
      return
    }
    this.save()
  }

  validateFields() {
    const name = this.stripName()
    let ok = true
    if (!name) {
      this.nameInputTarget.classList.add("is-needed")
      ok = false
    } else {
      this.nameInputTarget.classList.remove("is-needed")
    }
    if (this.countableValue) {
      const unit = this.unitInputTarget.value.trim()
      const quick = this.parseQuick(this.quickInputTarget.value)
      if (!unit) {
        this.unitInputTarget.classList.add("is-needed")
        ok = false
      } else {
        this.unitInputTarget.classList.remove("is-needed")
      }
      if (quick === null) {
        this.quickInputTarget.classList.add("is-needed")
        ok = false
      } else {
        this.quickInputTarget.classList.remove("is-needed")
      }
    }
    return ok
  }

  hasChanges() {
    const name = this.stripName()
    if (name !== this.initialNameValue.trim()) return true
    if (!this.countableValue) return false
    const unit = this.unitInputTarget.value.trim()
    const quick = this.parseQuick(this.quickInputTarget.value)
    if (unit !== this.initialUnitValue.trim()) return true
    if (quick !== Number(this.initialQuickValue)) return true
    return false
  }

  stripName() {
    return this.nameInputTarget.value.trim()
  }

  parseQuick(raw) {
    const text = String(raw ?? "").trim()
    if (text === "") return null
    const num = Number(text)
    if (!Number.isInteger(num) || num < 1 || num > 100_000) return null
    return num
  }

  async save() {
    if (this.inFlight) return
    this.inFlight = true
    this.setBusy(true)
    const token = document.querySelector("meta[name='csrf-token']")?.content
    const body = new FormData()
    body.append("authenticity_token", token || "")
    body.append("return_to", this.returnToValue)
    body.append("basic_edit_sheet", "1")
    body.append("habit[name]", this.stripName())
    if (this.countableValue) {
      body.append("habit[unit]", this.unitInputTarget.value.trim())
      body.append("habit[quick_add_amount]", String(this.parseQuick(this.quickInputTarget.value)))
    }
    this.appendMountainContext(body)

    try {
      const response = await fetch(this.updateUrlValue, {
        method: "PATCH",
        headers: {
          Accept: "text/vnd.turbo-stream.html",
          "X-CSRF-Token": token || ""
        },
        body,
        credentials: "same-origin"
      })
      if (response.status === 404) {
        this.handleGone()
        return
      }
      if (response.ok) {
        this.closeMenu()
        await applyTurboStreamFromResponse(response)
      } else {
        this.showNotice()
      }
    } catch (_err) {
      this.showNotice()
    } finally {
      this.inFlight = false
      this.setBusy(false)
    }
  }

  openDeleteConfirm(event) {
    event.preventDefault()
    if (this.inFlight || this.confirmOpen || !this.hasConfirmTemplateTarget) return
    const clone = this.confirmTemplateTarget.content.cloneNode(true)
    this.deleteSlotTarget.replaceChildren(clone)
    this.confirmOpen = true
    this.doneBtnTarget.hidden = true
  }

  keepDelete(event) {
    event?.preventDefault?.()
    this.restoreDeleteLink()
  }

  restoreDeleteLink() {
    if (!this.hasDeleteSlotTarget) return
    this.confirmOpen = false
    if (this.hasDoneBtnTarget) this.doneBtnTarget.hidden = false
    this.deleteSlotTarget.innerHTML = ""
    const btn = document.createElement("button")
    btn.type = "button"
    btn.className = "lp-basic-edit__delete-text"
    btn.dataset.basicEditSheetTarget = "deleteLink"
    btn.dataset.action = "click->basic-edit-sheet#openDeleteConfirm"
    btn.textContent = this.deleteBasicValue
    this.deleteSlotTarget.appendChild(btn)
  }

  async confirmDelete(event) {
    event.preventDefault()
    if (this.inFlight) return
    this.inFlight = true
    this.setBusy(true)
    this.hideNotice()
    const token = document.querySelector("meta[name='csrf-token']")?.content
    const body = new FormData()
    body.append("authenticity_token", token || "")
    body.append("return_to", this.returnToValue)
    body.append("_method", "delete")
    this.appendMountainContext(body)

    try {
      const response = await fetch(this.destroyUrlValue, {
        method: "POST",
        headers: {
          Accept: "text/vnd.turbo-stream.html",
          "X-CSRF-Token": token || ""
        },
        body,
        credentials: "same-origin"
      })
      if (response.status === 404) {
        this.handleGone()
        return
      }
      if (response.ok) {
        this.closeMenu()
        await applyTurboStreamFromResponse(response)
      } else {
        this.showNotice()
      }
    } catch (_err) {
      this.showNotice()
    } finally {
      this.inFlight = false
      this.setBusy(false)
    }
  }

  appendMountainContext(body) {
    if (this.returnToValue !== "mountain") return
    if (this.hasLifeJourneyIdValue) body.append("life_journey_id", String(this.lifeJourneyIdValue))
    if (this.hasGoalIdValue) body.append("goal_id", String(this.goalIdValue))
    if (this.hasPlanIdValue) body.append("plan_id", String(this.planIdValue))
  }

  handleGone() {
    this.closeMenu()
    this.removeStaleRow()
  }

  removeStaleRow() {
    if (this.returnToValue === "mountain") {
      document.getElementById(this.trailRowIdValue)?.remove()
    } else {
      document.getElementById(this.todayRowIdValue)?.remove()
    }
  }

  retry(event) {
    event.preventDefault()
    if (this.confirmOpen) this.confirmDelete(event)
    else this.save()
  }

  showNotice() {
    if (this.hasSaveNoticeTarget) this.saveNoticeTarget.hidden = false
  }

  hideNotice() {
    if (this.hasSaveNoticeTarget) this.saveNoticeTarget.hidden = true
  }

  setBusy(busy) {
    if (this.hasDoneBtnTarget) this.doneBtnTarget.disabled = busy
  }

  closeMenu() {
    const details = this.element.closest("details")
    if (!details) return
    const menu = details.closest("[data-controller~='tcard-menu']")
    const ctrl = menu && this.application.getControllerForElementAndIdentifier(menu, "tcard-menu")
    if (ctrl) ctrl.close()
    else details.open = false
  }
}
