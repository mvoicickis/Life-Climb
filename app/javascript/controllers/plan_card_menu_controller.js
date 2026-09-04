import { Controller } from "@hotwired/stimulus"

const OPEN_EVENT = "lp-rpg-path-menu:open"
const CAMP_OPEN_EVENT = "lp-trail-camp-menu:open"

// Plan card ⋮ menu — Edit / Delete use the shared LifePoints dialog.
export default class extends Controller {
  static targets = ["button", "menu", "editDialog", "deleteDialog", "objectivesDialog", "saveButton"]

  connect() {
    this._onPointer = (event) => this.onPointerDown(event)
    this._onKey = (event) => this.onKeydown(event)
    this._onOpenElsewhere = (event) => this.onOpenElsewhere(event)
    this._onReposition = () => this.positionMenu()
    this._onViewport = () => this.ensurePrimaryVisible()
    this._openEventName = this.campSheetMenu() ? CAMP_OPEN_EVENT : OPEN_EVENT
    window.addEventListener(this._openEventName, this._onOpenElsewhere)
  }

  disconnect() {
    this.close()
    this.closeEdit()
    this.closeDelete()
    this.closeObjectives()
    window.removeEventListener(this._openEventName, this._onOpenElsewhere)
  }

  campSheetMenu() {
    return this.element.hasAttribute("data-camp-menu-panel")
  }

  campSheetMenuHidden() {
    return this.campSheetMenu() && this.element.hidden
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    if (typeof event.stopImmediatePropagation === "function") {
      event.stopImmediatePropagation()
    }
    if (this.campSheetMenuHidden()) return
    if (this.menuTarget.hidden) {
      this.open()
    } else {
      this.close()
    }
  }

  edit(event) {
    event.preventDefault()
    event.stopPropagation()
    this.close()
    this.closeDelete()
    if (!this.hasEditDialogTarget) return

    this.editDialogTarget.showModal()
    this.bindDialogKeyboardGuards()
    const input = this.editDialogTarget.querySelector("input[name='title'], input, textarea")
    if (input) {
      input.focus()
      if (typeof input.select === "function") input.select()
    }
    this.ensurePrimaryVisible()
  }

  closeEdit(event) {
    event?.preventDefault()
    this.unbindDialogKeyboardGuards()
    if (!this.hasEditDialogTarget) return
    if (this.editDialogTarget.open) this.editDialogTarget.close()
  }

  confirmDelete(event) {
    event.preventDefault()
    event.stopPropagation()
    this.close()
    this.closeEdit()
    if (!this.hasDeleteDialogTarget) return
    this.deleteDialogTarget.showModal()
  }

  closeDelete(event) {
    event?.preventDefault()
    if (!this.hasDeleteDialogTarget) return
    if (this.deleteDialogTarget.open) this.deleteDialogTarget.close()
  }

  objectives(event) {
    event.preventDefault()
    event.stopPropagation()
    this.close()
    this.closeEdit()
    this.closeDelete()
    if (!this.hasObjectivesDialogTarget) return

    const frame = this.objectivesDialogTarget.querySelector("turbo-frame")
    const src = frame?.dataset?.src
    if (frame && src && frame.getAttribute("src") !== src) {
      frame.setAttribute("src", src)
    }
    this.objectivesDialogTarget.showModal()
  }

  closeObjectives(event) {
    event?.preventDefault()
    if (!this.hasObjectivesDialogTarget) return
    if (this.objectivesDialogTarget.open) this.objectivesDialogTarget.close()
  }

  bindDialogKeyboardGuards() {
    this.unbindDialogKeyboardGuards()
    if (!this.hasEditDialogTarget) return
    const input = this.editDialogTarget.querySelector("input[name='title'], input, textarea")
    this._onInputFocus = () => this.ensurePrimaryVisible()
    input?.addEventListener("focus", this._onInputFocus)
    window.visualViewport?.addEventListener("resize", this._onViewport)
    window.visualViewport?.addEventListener("scroll", this._onViewport)
  }

  unbindDialogKeyboardGuards() {
    if (this.hasEditDialogTarget) {
      const input = this.editDialogTarget.querySelector("input[name='title'], input, textarea")
      if (input && this._onInputFocus) input.removeEventListener("focus", this._onInputFocus)
    }
    window.visualViewport?.removeEventListener("resize", this._onViewport)
    window.visualViewport?.removeEventListener("scroll", this._onViewport)
  }

  ensurePrimaryVisible() {
    if (!this.hasEditDialogTarget || !this.editDialogTarget.open) return
    const primary =
      (this.hasSaveButtonTarget && this.saveButtonTarget) ||
      this.editDialogTarget.querySelector(".lp-strategy-sheet__btn.is-save, .lp-strategy-sheet__footer")
    if (!primary) return
    requestAnimationFrame(() => {
      primary.scrollIntoView({ block: "nearest", inline: "nearest", behavior: "smooth" })
    })
  }

  open() {
    if (this.campSheetMenuHidden()) return

    window.dispatchEvent(new CustomEvent(this._openEventName, { detail: { source: this } }))
    this.menuTarget.hidden = false
    this.buttonTarget.setAttribute("aria-expanded", "true")
    this.element.classList.add("is-menu-open")
    this.positionMenu()
    document.addEventListener("pointerdown", this._onPointer)
    document.addEventListener("keydown", this._onKey)
    window.addEventListener("resize", this._onReposition)
    const track = this.element.closest(".lp-rpg-plan-rail__track")
    if (track) {
      this._track = track
      track.addEventListener("scroll", this._onReposition, { passive: true })
    }
  }

  close() {
    if (!this.hasMenuTarget) return
    this.menuTarget.hidden = true
    if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-expanded", "false")
    this.element.classList.remove("is-menu-open")
    document.removeEventListener("pointerdown", this._onPointer)
    document.removeEventListener("keydown", this._onKey)
    window.removeEventListener("resize", this._onReposition)
    this._track?.removeEventListener("scroll", this._onReposition)
    this._track = null
  }

  positionMenu() {
    if (!this.hasMenuTarget || this.menuTarget.hidden || !this.hasButtonTarget) return

    const rect = this.buttonTarget.getBoundingClientRect()
    const menu = this.menuTarget
    menu.style.position = "fixed"
    menu.style.top = `${Math.round(rect.bottom + 4)}px`
    menu.style.left = "auto"
    menu.style.right = `${Math.round(window.innerWidth - rect.right)}px`
    menu.style.zIndex = "100"

    requestAnimationFrame(() => {
      const menuRect = menu.getBoundingClientRect()
      if (menuRect.bottom > window.innerHeight - 8) {
        menu.style.top = `${Math.round(rect.top - menuRect.height - 4)}px`
      }
      if (menuRect.left < 8) {
        menu.style.right = "auto"
        menu.style.left = "8px"
      }
    })
  }

  onPointerDown(event) {
    if (this.buttonTarget.contains(event.target) || this.menuTarget.contains(event.target)) return
    this.close()
  }

  onKeydown(event) {
    if (event.key === "Escape") this.close()
  }

  onOpenElsewhere(event) {
    if (event.detail?.source === this) return
    if (this.campSheetMenuHidden()) return
    this.close()
  }
}
