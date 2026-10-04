import { Controller } from "@hotwired/stimulus"
import { applyTurboStreamFromResponse } from "lib/apply_turbo_stream"

const ROW_STATE_CLASSES = ["is-done", "is-over", "is-hit"]

export default class extends Controller {
  static targets = [
    "totalLine",
    "totalCount",
    "totalUnit",
    "numDisplay",
    "numInput",
    "saveNotice",
    "minusBtn",
    "plusBtn"
  ]

  static values = {
    amount: Number,
    quick: Number,
    setUrl: String,
    habitId: Number,
    winNotSaved: String,
    todayId: String,
    metaId: String
  }

  connect() {
    this.confirmedAmount = this.amountValue
    this.pendingAmount = null
    this.inFlight = false
    this.editingExact = false
    this.syncDisplay(this.confirmedAmount)
  }

  stepMinus() {
    if (this.inFlight) return
    const next = Math.max(0, this.confirmedAmount - this.quickValue)
    this.saveTotal(next)
  }

  stepPlus() {
    if (this.inFlight) return
    const next = this.confirmedAmount + this.quickValue
    this.saveTotal(next)
  }

  openExact(event) {
    if (this.inFlight) return
    event.preventDefault()
    this.editingExact = true
    this.numDisplayTarget.hidden = true
    this.numInputTarget.hidden = false
    this.numInputTarget.value = String(this.confirmedAmount)
    this.numInputTarget.focus()
  }

  openExactKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.commitExact(true)
    } else if (event.key === "Escape") {
      event.preventDefault()
      this.commitExact(false)
    }
  }

  commitExactOnBlur() {
    this.commitExact(true)
  }

  commitExact(save) {
    if (!this.editingExact) return
    this.editingExact = false
    this.numInputTarget.hidden = true
    this.numDisplayTarget.hidden = false
    if (save) {
      const parsed = this.parseAmount(this.numInputTarget.value)
      if (parsed !== null) this.saveTotal(parsed)
      else this.syncDisplay(this.confirmedAmount)
    } else {
      this.syncDisplay(this.confirmedAmount)
    }
  }

  retrySave() {
    if (this.pendingAmount === null || this.inFlight) return
    this.saveTotal(this.pendingAmount)
  }

  async saveTotal(nextTotal) {
    if (this.inFlight) return
    const total = Math.max(0, nextTotal)
    this.pendingAmount = total
    this.hideNotice()
    this.inFlight = true
    this.setSteppersDisabled(true)

    const prior = this.confirmedAmount
    const token = document.querySelector("meta[name='csrf-token']")?.content
    const body = new FormData()
    body.append("authenticity_token", token || "")
    body.append("mode", "set")
    body.append("return_to", "today")
    body.append("daily_log[amount]", String(total))

    try {
      const response = await fetch(this.setUrlValue, {
        method: "POST",
        headers: {
          Accept: "text/vnd.turbo-stream.html",
          "X-CSRF-Token": token || ""
        },
        body,
        credentials: "same-origin"
      })

      if (response.ok) {
        const applied = await applyTurboStreamFromResponse(response)
        if (applied) {
          this.readAmountFromDom()
          this.syncRowState()
          this.pendingAmount = null
        } else {
          this.failSave(prior)
        }
      } else {
        this.failSave(prior)
      }
    } catch (_err) {
      this.failSave(prior)
    } finally {
      this.inFlight = false
      this.setSteppersDisabled(false)
    }
  }

  failSave(prior) {
    this.confirmedAmount = prior
    this.syncDisplay(prior)
    this.saveNoticeTarget.hidden = false
  }

  hideNotice() {
    if (this.hasSaveNoticeTarget) this.saveNoticeTarget.hidden = true
  }

  setSteppersDisabled(disabled) {
    if (this.hasMinusBtnTarget) this.minusBtnTarget.disabled = disabled
    if (this.hasPlusBtnTarget) this.plusBtnTarget.disabled = disabled
  }

  syncDisplay(amount) {
    const text = this.formatAmount(amount)
    if (this.hasTotalCountTarget) this.totalCountTarget.textContent = text
    if (this.hasNumDisplayTarget) this.numDisplayTarget.textContent = text
    if (this.hasTotalLineTarget) {
      this.totalLineTarget.classList.toggle("is-zero", amount === 0)
    }
    if (this.hasTotalUnitTarget) {
      this.totalUnitTarget.hidden = amount === 0
    }
    this.confirmedAmount = amount
    this.amountValue = amount
  }

  readAmountFromDom() {
    if (this.hasNumDisplayTarget) {
      const parsed = this.parseAmount(this.numDisplayTarget.textContent)
      if (parsed !== null) this.confirmedAmount = parsed
    }
  }

  syncRowState() {
    const meta = document.getElementById(this.metaIdValue)
    const row = document.getElementById(this.todayIdValue)
    if (!meta || !row) return
    const state = meta.dataset.basicRowState || ""
    ROW_STATE_CLASSES.forEach((klass) => row.classList.remove(klass))
    state.split(/\s+/).filter(Boolean).forEach((klass) => row.classList.add(klass))
  }

  parseAmount(raw) {
    const text = String(raw ?? "").trim().replace(/,/g, "")
    if (text === "") return null
    const num = Number(text)
    if (!Number.isFinite(num) || num < 0) return null
    return num
  }

  formatAmount(amount) {
    const num = Number(amount)
    if (!Number.isFinite(num)) return "0"
    return num === Math.floor(num) ? String(Math.floor(num)) : String(num)
  }

  done(event) {
    event.preventDefault()
    const row = document.getElementById(this.todayIdValue)
    const menu = row?.querySelector("[data-controller~='tcard-menu']")
    if (!menu) return
    const ctrl = this.application.getControllerForElementAndIdentifier(menu, "tcard-menu")
    ctrl?.close()
  }

  openEdit(event) {
    event.preventDefault()
    const row = document.getElementById(this.todayIdValue)
    if (!row) return
    const editHost = row.querySelector(".lp-dash-habit__edit-host")
    const editDetails = editHost?.querySelector("details")
    const logCtrl = this.application.getControllerForElementAndIdentifier(row, "tcard-menu")
    logCtrl?.close()

    requestAnimationFrame(() => {
      if (!editDetails || !editHost) return
      editDetails.open = true
    })
  }
}
