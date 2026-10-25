import { Controller } from "@hotwired/stimulus"
import { setTotal, retry, subscribe, formatAmount, parseAmount } from "lib/basic_today_save_queue"

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
    this.editingExact = false
    this.unsubscribe = subscribe(this.habitIdValue, (state) => this.onQueue(state), {
      amount: this.amountValue,
      setUrl: this.setUrlValue
    })
  }

  disconnect() {
    this.unsubscribe?.()
  }

  stepMinus() {
    const current = this.displayAmount()
    const next = Math.max(0, current - this.quickValue)
    this.saveTotal(next)
  }

  stepPlus() {
    const current = this.displayAmount()
    this.saveTotal(current + this.quickValue)
  }

  openExact(event) {
    event.preventDefault()
    this.editingExact = true
    this.numDisplayTarget.hidden = true
    this.numInputTarget.hidden = false
    this.numInputTarget.value = String(this.displayAmount())
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
      const parsed = parseAmount(this.numInputTarget.value)
      if (parsed !== null) this.saveTotal(parsed)
      else this.syncDisplay(this.displayAmount())
    } else {
      this.syncDisplay(this.displayAmount())
    }
  }

  retrySave() {
    retry(this.habitIdValue)
  }

  saveTotal(nextTotal) {
    setTotal(this.habitIdValue, nextTotal, { debounceMs: 0, setUrl: this.setUrlValue })
  }

  onQueue(state) {
    this.syncDisplay(state.localTotal)
    if (state.failed) {
      if (this.hasSaveNoticeTarget) this.saveNoticeTarget.hidden = false
    } else {
      this.hideNotice()
    }
    if (!state.inFlight && state.localTotal === state.confirmedTotal && !state.failed) {
      this.syncRowState()
    }
  }

  hideNotice() {
    if (this.hasSaveNoticeTarget) this.saveNoticeTarget.hidden = true
  }

  syncDisplay(amount) {
    const text = formatAmount(amount)
    if (this.hasTotalCountTarget) this.totalCountTarget.textContent = text
    if (this.hasNumDisplayTarget) this.numDisplayTarget.textContent = text
    if (this.hasTotalLineTarget) {
      this.totalLineTarget.classList.toggle("is-zero", amount === 0)
    }
    if (this.hasTotalUnitTarget) {
      this.totalUnitTarget.hidden = amount === 0
    }
    this.amountValue = amount
  }

  displayAmount() {
    if (this.hasNumDisplayTarget) {
      const parsed = parseAmount(this.numDisplayTarget.textContent)
      if (parsed !== null) return parsed
    }
    return this.amountValue
  }

  syncRowState() {
    const meta = document.getElementById(this.metaIdValue)
    const row = document.getElementById(this.todayIdValue)
    if (!meta || !row) return
    const state = meta.dataset.basicRowState || ""
    ROW_STATE_CLASSES.forEach((klass) => row.classList.remove(klass))
    state.split(/\s+/).filter(Boolean).forEach((klass) => row.classList.add(klass))
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
