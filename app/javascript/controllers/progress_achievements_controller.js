import { Controller } from "@hotwired/stimulus"

// Achievement badge detail dialog.
export default class extends Controller {
  static targets = ["dialog", "title", "hint", "icon"]

  open(event) {
    const button = event.currentTarget
    if (!this.hasDialogTarget) return
    this.iconTarget.textContent = button.dataset.icon || ""
    this.titleTarget.textContent = button.dataset.title || ""
    this.hintTarget.textContent = button.dataset.hint || ""
    if (typeof this.dialogTarget.showModal === "function") {
      this.dialogTarget.showModal()
    } else {
      this.dialogTarget.setAttribute("open", "open")
    }
  }

  close() {
    if (!this.hasDialogTarget) return
    if (typeof this.dialogTarget.close === "function") {
      this.dialogTarget.close()
    } else {
      this.dialogTarget.removeAttribute("open")
    }
  }
}
