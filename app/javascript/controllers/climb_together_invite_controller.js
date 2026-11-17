import { Controller } from "@hotwired/stimulus"

// You page: Climb together confirm sheet → open the share sheet with invite link.
export default class extends Controller {
  static targets = ["dialog", "backdrop", "panel"]

  connect() {
    this.previouslyFocused = null
    this.boundKeydown = this.onKeydown.bind(this)
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

  send(event) {
    event?.preventDefault()
    this.teardownOpenState()
    const share = this.application.getControllerForElementAndIdentifier(this.element, "share")
    share?.open(event)
  }

  teardownOpenState() {
    if (!this.hasDialogTarget || this.dialogTarget.hidden) {
      document.removeEventListener("keydown", this.boundKeydown)
      return
    }

    this.dialogTarget.classList.remove("is-open")
    document.body.classList.remove("share-sheet-open")
    document.removeEventListener("keydown", this.boundKeydown)
    this.dialogTarget.setAttribute("aria-hidden", "true")

    window.setTimeout(() => {
      this.dialogTarget.hidden = true
      if (this.previouslyFocused?.focus) this.previouslyFocused.focus()
      this.previouslyFocused = null
    }, 180)
  }
}
