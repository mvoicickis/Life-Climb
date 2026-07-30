import { Controller } from "@hotwired/stimulus"

const OPEN_EVENT = "lp-rpg-path-menu:open"

// Plan card ⋮ menu — Edit opens the shared LifePoints dialog; Delete is still a placeholder.
export default class extends Controller {
  static targets = ["button", "menu", "editDialog", "saveButton"]

  connect() {
    this._onPointer = (event) => this.onPointerDown(event)
    this._onKey = (event) => this.onKeydown(event)
    this._onOpenElsewhere = (event) => this.onOpenElsewhere(event)
    this._onReposition = () => this.positionMenu()
    this._onViewport = () => this.ensurePrimaryVisible()
    window.addEventListener(OPEN_EVENT, this._onOpenElsewhere)
  }

  disconnect() {
    this.close()
    this.closeEdit()
    window.removeEventListener(OPEN_EVENT, this._onOpenElsewhere)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
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

  // Placeholder until Delete Plan is implemented.
  noop(event) {
    event.preventDefault()
    event.stopPropagation()
    this.close()
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
    window.dispatchEvent(new CustomEvent(OPEN_EVENT, { detail: { source: this } }))
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
    menu.style.zIndex = "80"

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
    if (event.detail?.source !== this) this.close()
  }
}
