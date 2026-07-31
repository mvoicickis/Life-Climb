import { Controller } from "@hotwired/stimulus"

// Active Destination dropdown + shared Create Destination dialog.
export default class extends Controller {
  static targets = ["button", "menu", "createDialog", "saveButton"]

  connect() {
    this._onPointer = (event) => this.onPointerDown(event)
    this._onKey = (event) => this.onKeydown(event)
    this._onViewport = () => this.ensurePrimaryVisible()
    this._onReposition = () => this.positionMenu()
  }

  disconnect() {
    this.close()
    this.closeCreate()
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    if (!this.hasMenuTarget) {
      this.openCreate(event)
      return
    }
    if (this.menuTarget.hidden) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    if (!this.hasMenuTarget) return
    this.menuTarget.hidden = false
    this.element.classList.add("is-open")
    this.buttonTarget?.setAttribute("aria-expanded", "true")
    this.positionMenu()
    document.addEventListener("pointerdown", this._onPointer)
    document.addEventListener("keydown", this._onKey)
    window.addEventListener("resize", this._onReposition)
    window.addEventListener("scroll", this._onReposition, true)
  }

  close() {
    if (!this.hasMenuTarget) return
    this.menuTarget.hidden = true
    this.element.classList.remove("is-open")
    this.buttonTarget?.setAttribute("aria-expanded", "false")
    document.removeEventListener("pointerdown", this._onPointer)
    document.removeEventListener("keydown", this._onKey)
    window.removeEventListener("resize", this._onReposition)
    window.removeEventListener("scroll", this._onReposition, true)
  }

  positionMenu() {
    if (!this.hasMenuTarget || this.menuTarget.hidden || !this.hasButtonTarget) return

    const rect = this.buttonTarget.getBoundingClientRect()
    const menu = this.menuTarget
    menu.style.position = "fixed"
    menu.style.top = `${Math.round(rect.bottom + 6)}px`
    menu.style.left = `${Math.round(rect.left)}px`
    menu.style.right = "auto"
    menu.style.transform = "none"
    menu.style.zIndex = "90"

    requestAnimationFrame(() => {
      const menuRect = menu.getBoundingClientRect()
      if (menuRect.right > window.innerWidth - 8) {
        menu.style.left = "auto"
        menu.style.right = "8px"
      }
      if (menuRect.left < 8) {
        menu.style.left = "8px"
        menu.style.right = "auto"
      }
      if (menuRect.bottom > window.innerHeight - 8) {
        menu.style.top = `${Math.round(rect.top - menuRect.height - 6)}px`
      }
    })
  }

  openCreate(event) {
    event?.preventDefault()
    event?.stopPropagation()
    this.close()
    if (!this.hasCreateDialogTarget) return

    this.createDialogTarget.showModal()
    this.bindDialogKeyboardGuards()
    const input = this.createDialogTarget.querySelector("input[name='title'], input, textarea")
    if (input) {
      input.focus()
      if (typeof input.select === "function") input.select()
    }
    this.ensurePrimaryVisible()
  }

  closeCreate(event) {
    event?.preventDefault()
    this.unbindDialogKeyboardGuards()
    if (!this.hasCreateDialogTarget) return
    if (this.createDialogTarget.open) this.createDialogTarget.close()
    this.buttonTarget?.focus()
  }

  onPointerDown(event) {
    if (this.element.contains(event.target)) return
    this.close()
  }

  onKeydown(event) {
    if (event.key !== "Escape") return
    if (this.hasCreateDialogTarget && this.createDialogTarget.open) {
      this.closeCreate(event)
      return
    }
    this.close()
    this.buttonTarget?.focus()
  }

  bindDialogKeyboardGuards() {
    this.unbindDialogKeyboardGuards()
    if (!this.hasCreateDialogTarget) return
    const input = this.createDialogTarget.querySelector("input[name='title'], input, textarea")
    this._onInputFocus = () => this.ensurePrimaryVisible()
    input?.addEventListener("focus", this._onInputFocus)
    window.visualViewport?.addEventListener("resize", this._onViewport)
    window.visualViewport?.addEventListener("scroll", this._onViewport)
  }

  unbindDialogKeyboardGuards() {
    if (this.hasCreateDialogTarget) {
      const input = this.createDialogTarget.querySelector("input[name='title'], input, textarea")
      if (input && this._onInputFocus) input.removeEventListener("focus", this._onInputFocus)
    }
    window.visualViewport?.removeEventListener("resize", this._onViewport)
    window.visualViewport?.removeEventListener("scroll", this._onViewport)
  }

  ensurePrimaryVisible() {
    if (!this.hasCreateDialogTarget || !this.createDialogTarget.open) return
    const primary =
      (this.hasSaveButtonTarget && this.saveButtonTarget) ||
      this.createDialogTarget.querySelector(".lp-strategy-sheet__btn.is-save, .lp-strategy-sheet__footer")
    if (!primary) return
    requestAnimationFrame(() => {
      primary.scrollIntoView({ block: "nearest", inline: "nearest", behavior: "smooth" })
    })
  }
}
