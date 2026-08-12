import { Controller } from "@hotwired/stimulus"

// Opens/closes the Today quest steps sheet (native <dialog>).
export default class extends Controller {
  static targets = ["dialog"]

  open(event) {
    event?.preventDefault()
    if (!this.hasDialogTarget) return
    if (typeof this.dialogTarget.showModal === "function") {
      this.dialogTarget.showModal()
    }
  }

  close(event) {
    event?.preventDefault()
    if (!this.hasDialogTarget) return
    this.dialogTarget.close()
  }

  backdropClose(event) {
    if (!this.hasDialogTarget) return
    if (event.target === this.dialogTarget) this.dialogTarget.close()
  }
}
