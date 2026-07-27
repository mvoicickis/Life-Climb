import { Controller } from "@hotwired/stimulus"

// Living mountain: tiny pin menus, long-press radial, sheet for deep edit.
export default class extends Controller {
  static targets = ["marker", "sheet", "menu", "radial"]
  static values = {
    open: Boolean,
    openMenu: Boolean,
    focusSheet: String,
    focusMenu: String
  }

  connect() {
    this.pressTimer = null
    this.pressNodeId = null
    this.longPressed = false
    if (this.openMenuValue) this.openFocusedMenu()
    else if (this.openValue) this.openFocusedSheet({ add: true })
  }

  disconnect() {
    this.clearPress()
  }

  selectPin(event) {
    if (this.longPressed) {
      event.preventDefault()
      return
    }
    event.preventDefault()
    const marker = event.currentTarget
    const kind = marker.dataset.nodeKind
    const nodeId = marker.dataset.nodeId
    const title = marker.getAttribute("title") || ""

    // Camp notebook IA: Goal/Plan open the notebook — not tiny menus or L3 zoom.
    if (kind === "goal") {
      this.notebook()?.focusGoal()
      return
    }
    if (kind === "plan") {
      this.notebook()?.openPlanById(nodeId, title)
      return
    }

    const menuId = marker.dataset.menuId
    if (menuId) this.openMenuById(menuId)
  }

  openSheetFromButton(event) {
    event.preventDefault()
    const sheetId = event.currentTarget.dataset.sheetId
    this.openSheetById(sheetId, { edit: true })
  }

  menuZoom(event) {
    event.preventDefault()
    const btn = event.currentTarget
    this.closeOpenMenus()
    this.camera()?.zoomTo({ id: btn.dataset.nodeId, kind: btn.dataset.nodeKind, push: true })
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

  closeMenu(event) {
    const menu = event.currentTarget.closest("dialog")
    menu?.close()
  }

  closeOpenMenus() {
    this.menuTargets?.forEach((menu) => {
      if (menu.open) menu.close()
    })
    document.querySelectorAll("dialog.lp-strategy-menu[open]").forEach((menu) => menu.close())
  }

  menuAdd(event) {
    event.preventDefault()
    const sheetId = event.currentTarget.dataset.sheetId
    event.currentTarget.closest("dialog")?.close()
    this.openSheetById(sheetId, { add: true })
  }

  menuEdit(event) {
    event.preventDefault()
    const sheetId = event.currentTarget.dataset.sheetId
    event.currentTarget.closest("dialog")?.close()
    this.openSheetById(sheetId, { edit: true })
  }

  menuMore(event) {
    event.preventDefault()
    const sheetId = event.currentTarget.dataset.sheetId
    event.currentTarget.closest("dialog")?.close()
    this.openSheetById(sheetId, { edit: true })
  }

  openOverflow(event) {
    event.preventDefault()
    const btn = event.currentTarget
    const menuId = btn.dataset.menuId
    const sheetId = btn.dataset.sheetId
    if (menuId) this.openMenuById(menuId)
    else this.openSheetById(sheetId, { edit: true })
  }

  // Back-compat aliases used by older templates
  peek(event) {
    this.selectPin(event)
  }

  closePeek(event) {
    this.closeMenu(event)
  }

  peekAdd(event) {
    this.menuAdd(event)
  }

  peekMore(event) {
    this.menuMore(event)
  }

  focusedSheetId() {
    if (this.hasFocusSheetValue && this.focusSheetValue) return this.focusSheetValue
    const preferred = this.element.querySelector(".lp-strategy-marker.is-today, .lp-strategy-marker.is-lit")
    return preferred?.dataset?.sheetId
  }

  focusedMenuId() {
    if (this.hasFocusMenuValue && this.focusMenuValue) return this.focusMenuValue
    const preferred = this.element.querySelector(".lp-strategy-marker.is-today, .lp-strategy-marker.is-lit")
    return preferred?.dataset?.menuId
  }

  openFocusedMenu() {
    const id = this.focusedMenuId()
    if (id) this.openMenuById(id)
  }

  openFocusedPeek() {
    this.openFocusedMenu()
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

  openMenuById(menuId) {
    if (!menuId) return
    this.closeOpenMenus()
    const menu = document.getElementById(menuId)
    if (!menu) return
    if (typeof menu.showModal === "function" && !menu.open) menu.showModal()
    else menu.setAttribute("open", "")
  }

  openPeekById(peekId) {
    // Legacy peeks renamed to menus with strategy-menu- ids
    const id = peekId?.replace("strategy-peek-", "strategy-menu-") || peekId
    this.openMenuById(id)
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

  camera() {
    return this.application.getControllerForElementAndIdentifier(this.element, "strategy-camera")
  }

  notebook() {
    return this.application.getControllerForElementAndIdentifier(this.element, "strategy-notebook")
  }
}
