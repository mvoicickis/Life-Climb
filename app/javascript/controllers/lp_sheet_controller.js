import { Controller } from "@hotwired/stimulus"

// Opens <dialog> when the Turbo Frame loads sheet content.
export default class extends Controller {
  static targets = ["dialog", "frame"]

  connect() {
    this.boundFrameLoad = this.onFrameLoad.bind(this)
    if (this.hasFrameTarget) {
      this.frameTarget.addEventListener("turbo:frame-load", this.boundFrameLoad)
    }
  }

  disconnect() {
    if (this.hasFrameTarget) {
      this.frameTarget.removeEventListener("turbo:frame-load", this.boundFrameLoad)
    }
  }

  onFrameLoad() {
    if (!this.hasDialogTarget) return
    if (this.frameTarget.innerText.trim().length === 0) return
    if (!this.dialogTarget.open) this.dialogTarget.showModal()
  }

  close() {
    if (this.hasDialogTarget && this.dialogTarget.open) {
      this.dialogTarget.close()
    }
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
