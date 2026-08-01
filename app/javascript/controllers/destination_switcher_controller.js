import { Controller } from "@hotwired/stimulus"

// Destination create dialog + swipe navigation (arrows/dots use Turbo links).
export default class extends Controller {
  static targets = ["button", "createDialog", "saveButton", "prevLink", "nextLink"]

  connect() {
    this._onViewport = () => this.ensurePrimaryVisible()
    this._swipeX = null
  }

  disconnect() {
    this.closeCreate()
    this._swipeX = null
  }

  swipeStart(event) {
    if (event.pointerType === "mouse" && event.button !== 0) return
    if (event.target.closest("a, button, input, textarea, summary, dialog")) return
    this._swipeX = event.clientX
    this._swipeY = event.clientY
  }

  swipeCancel() {
    this._swipeX = null
  }

  swipeEnd(event) {
    if (this._swipeX == null) return
    const dx = event.clientX - this._swipeX
    const dy = event.clientY - (this._swipeY || event.clientY)
    this._swipeX = null
    this._swipeY = null

    if (Math.abs(dx) < 48 || Math.abs(dx) < Math.abs(dy)) return

    const link = dx < 0
      ? (this.hasNextLinkTarget ? this.nextLinkTarget : null)
      : (this.hasPrevLinkTarget ? this.prevLinkTarget : null)
    if (!link) return
    link.click()
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
