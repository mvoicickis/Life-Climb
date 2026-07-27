import { Controller } from "@hotwired/stimulus"

// Living mountain: peek cards by default, long-press radial for power tools.
export default class extends Controller {
  static targets = ["marker", "sheet", "peek", "radial"]
  static values = {
    open: Boolean,
    openPeek: Boolean,
    focusSheet: String,
    focusPeek: String
  }

  connect() {
    this.pressTimer = null
    this.pressNodeId = null
    this.longPressed = false
    if (this.openPeekValue) this.openFocusedPeek()
    else if (this.openValue) this.openFocusedSheet({ add: true })
  }

  disconnect() {
    this.clearPress()
  }

  peek(event) {
    if (this.longPressed) {
      event.preventDefault()
      return
    }
    event.preventDefault()
    const peekId = event.currentTarget.dataset.peekId
    if (peekId) this.openPeekById(peekId)
  }

  press(event) {
    if (event.pointerType === "mouse" && event.button !== 0) return
    this.longPressed = false
    this.pressNodeId = event.currentTarget.dataset.nodeId
    this.clearPress()
    this.pressTimer = window.setTimeout(() => {
      this.longPressed = true
      this.showRadial(event.currentTarget, event.clientX, event.clientY)
    }, 480)
  }

  release(event) {
    const wasLong = this.longPressed
    this.clearPress()
    if (wasLong) {
      event.preventDefault()
      event.stopPropagation()
    }
  }

  cancel() {
    this.clearPress()
  }

  menu(event) {
    event.preventDefault()
    this.longPressed = true
    this.pressNodeId = event.currentTarget.dataset.nodeId
    this.showRadial(event.currentTarget, event.clientX, event.clientY)
  }

  clearPress() {
    if (this.pressTimer) window.clearTimeout(this.pressTimer)
    this.pressTimer = null
  }

  showRadial(marker, x, y) {
    if (!this.hasRadialTarget) return
    const radial = this.radialTarget
    radial.hidden = false
    radial.dataset.nodeId = marker.dataset.nodeId
    radial.dataset.canAdd = marker.dataset.canAdd
    radial.dataset.sheetId = marker.dataset.sheetId
    const rect = this.element.getBoundingClientRect()
    radial.style.left = `${Math.min(Math.max(x - rect.left, 48), rect.width - 48)}px`
    radial.style.top = `${Math.min(Math.max(y - rect.top, 48), rect.height - 48)}px`
    radial.classList.add("is-open")
  }

  hideRadial() {
    if (!this.hasRadialTarget) return
    this.radialTarget.hidden = true
    this.radialTarget.classList.remove("is-open")
  }

  radialEdit(event) {
    event.preventDefault()
    this.openSheetById(this.radialTarget.dataset.sheetId, { edit: true })
    this.hideRadial()
  }

  radialHelp(event) {
    event.preventDefault()
    this.openSheetById(this.radialTarget.dataset.sheetId, { help: true })
    this.hideRadial()
  }

  radialAdd(event) {
    event.preventDefault()
    if (this.radialTarget.dataset.canAdd === "false") return
    this.openSheetById(this.radialTarget.dataset.sheetId, { add: true })
    this.hideRadial()
  }

  radialDelete(event) {
    event.preventDefault()
    const sheet = this.findSheet(this.radialTarget.dataset.sheetId)
    const btn = sheet?.querySelector(".lp-strategy-sheet__btn.is-delete")
    this.hideRadial()
    btn?.click()
  }

  closeSheet(event) {
    const sheet = event.currentTarget.closest("dialog")
    sheet?.close()
  }

  closePeek(event) {
    const peek = event.currentTarget.closest("dialog")
    peek?.close()
  }

  peekAdd(event) {
    event.preventDefault()
    const sheetId = event.currentTarget.dataset.sheetId
    event.currentTarget.closest("dialog")?.close()
    this.openSheetById(sheetId, { add: true })
  }

  peekMore(event) {
    event.preventDefault()
    const sheetId = event.currentTarget.dataset.sheetId
    event.currentTarget.closest("dialog")?.close()
    this.openSheetById(sheetId, { edit: true })
  }

  focusedSheetId() {
    if (this.hasFocusSheetValue && this.focusSheetValue) return this.focusSheetValue
    const preferred = this.element.querySelector(".lp-strategy-marker.is-today, .lp-strategy-marker.is-lit")
    return preferred?.dataset?.sheetId
  }

  focusedPeekId() {
    if (this.hasFocusPeekValue && this.focusPeekValue) return this.focusPeekValue
    const preferred = this.element.querySelector(".lp-strategy-marker.is-today, .lp-strategy-marker.is-lit")
    return preferred?.dataset?.peekId
  }

  openFocusedPeek() {
    const id = this.focusedPeekId()
    if (id) this.openPeekById(id)
  }

  openFocusedSheet(opts = {}) {
    const id = this.focusedSheetId()
    if (id) this.openSheetById(id, opts)
  }

  openFocusedAdd(event) {
    event?.preventDefault()
    const focusId = this.hasFocusSheetValue ? this.focusSheetValue : null
    if (focusId) {
      const marker = this.element.querySelector(`.lp-strategy-marker[data-sheet-id="${focusId}"]`)
      if (marker?.dataset?.canAdd === "true") {
        this.openSheetById(focusId, { add: true })
        return
      }
    }
    const marker =
      this.element.querySelector(".lp-strategy-marker.is-lit[data-can-add='true']") ||
      this.element.querySelector(".lp-strategy-marker[data-can-add='true']")
    if (!marker) return
    this.openSheetById(marker.dataset.sheetId, { add: true })
  }

  openPeekById(peekId) {
    if (!peekId) return
    const peek = document.getElementById(peekId)
    if (!peek) return
    if (typeof peek.showModal === "function" && !peek.open) peek.showModal()
    else peek.setAttribute("open", "")
  }

  openSheetById(sheetId, opts = {}) {
    if (!sheetId) return
    const sheet = this.findSheet(sheetId)
    if (!sheet) return
    if (typeof sheet.showModal === "function" && !sheet.open) sheet.showModal()
    else sheet.setAttribute("open", "")
    if (opts.edit) sheet.querySelector(".lp-strategy-sheet__edit")?.setAttribute("open", "")
    if (opts.add) sheet.querySelector(".lp-strategy-sheet__add")?.setAttribute("open", "")
    if (opts.help) sheet.querySelector("[data-action='strategist#requestHelp']")?.click()
  }

  findSheet(sheetId) {
    return document.getElementById(sheetId)
  }
}
