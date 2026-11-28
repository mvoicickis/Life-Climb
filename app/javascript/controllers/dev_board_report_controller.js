import { Controller } from "@hotwired/stimulus"

// Dev board — report bug or idea (native <dialog>).
export default class extends Controller {
  static targets = ["dialog"]
  static values = { open: Boolean }

  connect() {
    if (this.openValue) this.showDialog()
  }

  open(event) {
    event?.preventDefault()
    this.showDialog()
  }

  close(event) {
    event?.preventDefault()
    if (!this.hasDialogTarget) return
    if (this.dialogTarget.open) this.dialogTarget.close()
  }

  backdropClose(event) {
    if (!this.hasDialogTarget) return
    if (event.target === this.dialogTarget) this.close()
  }

  showDialog() {
    if (!this.hasDialogTarget) return
    if (typeof this.dialogTarget.showModal === "function") {
      this.dialogTarget.showModal()
    }
    const field = this.dialogTarget.querySelector(
      "input[type='text'], textarea, select, input:not([type='hidden'])"
    )
    field?.focus()
  }
}