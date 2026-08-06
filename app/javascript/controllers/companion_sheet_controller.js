import { Controller } from "@hotwired/stimulus"

// Settings companion picker — compact trigger opens a mobile bottom sheet.
export default class extends Controller {
  static targets = ["dialog", "backdrop", "panel", "handle", "trigger"]

  connect() {
    this.previouslyFocused = null
    this.boundKeydown = this.onKeydown.bind(this)
    this.drag = null
    this.boundPointerMove = this.onPointerMove.bind(this)
    this.boundPointerUp = this.onPointerUp.bind(this)
  }

  disconnect() {
    this.teardownOpenState()
    this.endDrag()
  }

  open(event) {
    event?.preventDefault()
    if (!this.hasDialogTarget) return

    this.previouslyFocused = document.activeElement
    this.dialogTarget.hidden = false
    this.dialogTarget.setAttribute("aria-hidden", "false")
    this.setExpanded(true)
    document.body.classList.add("companion-sheet-open")
    document.addEventListener("keydown", this.boundKeydown)

    requestAnimationFrame(() => {
      this.dialogTarget.classList.add("is-open")
      this.panelTarget.style.transform = ""
      const focusable = this.panelTarget.querySelector(
        "button, [href], input:not([type='hidden']), [tabindex]:not([tabindex='-1'])"
      )
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

  // Selecting a companion submits the existing PATCH form.
  pick(event) {
    const input = event.target
    if (!(input instanceof HTMLInputElement) || input.type !== "radio") return
    if (input.name !== "user[character]") return

    const form = input.form
    if (!form) return

    this.teardownOpenState()
    if (typeof form.requestSubmit === "function") {
      form.requestSubmit()
    } else {
      form.submit()
    }
  }

  startDrag(event) {
    if (!this.dialogTarget.classList.contains("is-open")) return
    if (event.pointerType === "mouse" && event.button !== 0) return

    this.drag = {
      startY: event.clientY,
      pointerId: event.pointerId
    }
    this.handleTarget?.setPointerCapture?.(event.pointerId)
    this.panelTarget.classList.add("is-dragging")
    window.addEventListener("pointermove", this.boundPointerMove)
    window.addEventListener("pointerup", this.boundPointerUp)
    window.addEventListener("pointercancel", this.boundPointerUp)
  }

  onPointerMove(event) {
    if (!this.drag || event.pointerId !== this.drag.pointerId) return
    const delta = Math.max(0, event.clientY - this.drag.startY)
    this.panelTarget.style.transform = `translateY(${delta}px)`
  }

  onPointerUp(event) {
    if (!this.drag || event.pointerId !== this.drag.pointerId) return
    const delta = Math.max(0, event.clientY - this.drag.startY)
    this.endDrag()

    if (delta > 80) {
      this.close()
      return
    }

    this.panelTarget.style.transform = ""
  }

  endDrag() {
    this.drag = null
    this.panelTarget?.classList.remove("is-dragging")
    window.removeEventListener("pointermove", this.boundPointerMove)
    window.removeEventListener("pointerup", this.boundPointerUp)
    window.removeEventListener("pointercancel", this.boundPointerUp)
  }

  onKeydown(event) {
    if (event.key === "Escape") this.close(event)
  }

  setExpanded(open) {
    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", open ? "true" : "false")
    }
  }

  teardownOpenState() {
    if (!this.hasDialogTarget) {
      document.removeEventListener("keydown", this.boundKeydown)
      return
    }

    this.endDrag()
    this.dialogTarget.classList.remove("is-open")
    this.panelTarget.style.transform = ""
    this.setExpanded(false)
    document.body.classList.remove("companion-sheet-open")
    document.removeEventListener("keydown", this.boundKeydown)
    this.dialogTarget.setAttribute("aria-hidden", "true")

    window.setTimeout(() => {
      this.dialogTarget.hidden = true
      if (this.previouslyFocused?.focus) this.previouslyFocused.focus()
    }, 200)
  }
}
