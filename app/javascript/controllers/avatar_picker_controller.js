import { Controller } from "@hotwired/stimulus"

// You page: social animal avatar sheet. Save on tap; close on success.
export default class extends Controller {
  static targets = ["dialog", "backdrop", "panel", "error"]
  static values = {
    notSaved: { type: String, default: "Not saved" }
  }

  connect() {
    this.previouslyFocused = null
    this.boundKeydown = this.onKeydown.bind(this)
  }

  disconnect() {
    document.body.classList.remove("share-sheet-open")
    document.removeEventListener("keydown", this.boundKeydown)
  }

  open(event) {
    event?.preventDefault()
    event?.stopPropagation()
    this.clearError()

    this.previouslyFocused = document.activeElement
    this.dialogTarget.hidden = false
    this.dialogTarget.setAttribute("aria-hidden", "false")
    document.body.classList.add("share-sheet-open")
    document.addEventListener("keydown", this.boundKeydown)

    requestAnimationFrame(() => {
      this.dialogTarget.classList.add("is-open")
      const focusable = this.panelTarget.querySelector("button, [href], [tabindex]:not([tabindex='-1'])")
      focusable?.focus()
    })
  }

  close(event) {
    event?.preventDefault()
    this.teardownOpenState()
  }

  closeOnBackdrop(event) {
    if (event.target === this.backdropTarget) this.close(event)
  }

  onKeydown(event) {
    if (event.key === "Escape") this.close(event)
  }

  submitEnd(event) {
    if (event.detail?.success) {
      this.clearError()
      this.teardownOpenState({ restoreFocus: false })
      return
    }

    this.showError()
  }

  showError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = this.notSavedValue
    this.errorTarget.hidden = false
  }

  clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ""
    this.errorTarget.hidden = true
  }

  teardownOpenState({ restoreFocus = true } = {}) {
    if (!this.hasDialogTarget || this.dialogTarget.hidden) {
      document.removeEventListener("keydown", this.boundKeydown)
      return
    }

    this.dialogTarget.classList.remove("is-open")
    document.body.classList.remove("share-sheet-open")
    document.removeEventListener("keydown", this.boundKeydown)
    this.dialogTarget.setAttribute("aria-hidden", "true")

    window.setTimeout(() => {
      if (!this.hasDialogTarget) return
      this.dialogTarget.hidden = true
      if (restoreFocus && this.previouslyFocused?.focus) {
        this.previouslyFocused.focus()
      }
      this.previouslyFocused = null
    }, 180)
  }
}
