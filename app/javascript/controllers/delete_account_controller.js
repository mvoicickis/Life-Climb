import { Controller } from "@hotwired/stimulus"

// You page: delete-account confirmation sheet.
export default class extends Controller {
  static targets = ["dialog", "backdrop", "panel", "password", "submit", "form", "error", "errorText"]
  static values = { open: Boolean }

  connect() {
    this.previouslyFocused = null
    this.boundKeydown = this.onKeydown.bind(this)
    this.submitting = false

    if (this.openValue) {
      requestAnimationFrame(() => this.open())
    }
  }

  disconnect() {
    this.teardownOpenState()
  }

  open(event) {
    event?.preventDefault()
    event?.stopPropagation()

    this.previouslyFocused = document.activeElement
    this.dialogTarget.hidden = false
    this.dialogTarget.setAttribute("aria-hidden", "false")
    document.body.classList.add("share-sheet-open")
    document.addEventListener("keydown", this.boundKeydown)

    requestAnimationFrame(() => {
      this.dialogTarget.classList.add("is-open")
      this.passwordTarget?.focus()
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

  passwordInput() {
    const hasText = this.passwordTarget.value.trim().length > 0
    this.submitTarget.disabled = !hasText || this.submitting
  }

  submit(event) {
    if (this.submitting) {
      event.preventDefault()
      return
    }

    this.submitting = true
    this.submitTarget.disabled = true
  }

  teardownOpenState() {
    if (!this.hasDialogTarget || this.dialogTarget.hidden) return

    this.dialogTarget.classList.remove("is-open")
    this.dialogTarget.hidden = true
    this.dialogTarget.setAttribute("aria-hidden", "true")
    document.body.classList.remove("share-sheet-open")
    document.removeEventListener("keydown", this.boundKeydown)

    if (this.previouslyFocused?.focus) {
      this.previouslyFocused.focus()
    }
    this.previouslyFocused = null
  }
}
