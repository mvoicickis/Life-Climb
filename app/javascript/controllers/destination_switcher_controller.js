import { Controller } from "@hotwired/stimulus"

// Destination create dialog (carousel arrows use Turbo links for Focus).
export default class extends Controller {
  static targets = ["button", "createDialog", "saveButton"]

  connect() {
    this._onViewport = () => this.ensurePrimaryVisible()
  }

  disconnect() {
    this.closeCreate()
  }

  openCreate(event) {
    event?.preventDefault()
    event?.stopPropagation()
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
