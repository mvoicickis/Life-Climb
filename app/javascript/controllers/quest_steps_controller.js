import { Controller } from "@hotwired/stimulus"
import { dismissDialogAnimated } from "lib/lp_today_sheet_dismiss"

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
    if (!this.hasDialogTarget || !this.dialogTarget.open) return
    dismissDialogAnimated(this.dialogTarget)
  }

  backdropClose(event) {
    if (!this.hasDialogTarget) return
    if (event.target === this.dialogTarget) this.close()
  }
}