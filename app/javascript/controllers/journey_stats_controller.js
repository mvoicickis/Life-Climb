import { Controller } from "@hotwired/stimulus"

// Add-Tracker dialog on the Journey stats section.
export default class extends Controller {
  static targets = ["dialog"]

  open(event) {
    event?.preventDefault?.()
    if (!this.hasDialogTarget) return
    if (typeof this.dialogTarget.showModal === "function") {
      this.dialogTarget.showModal()
    } else {
      this.dialogTarget.setAttribute("open", "open")
    }
  }

  close(event) {
    event?.preventDefault?.()
    if (!this.hasDialogTarget) return
    if (typeof this.dialogTarget.close === "function") {
      this.dialogTarget.close()
    } else {
      this.dialogTarget.removeAttribute("open")
    }
  }
}
