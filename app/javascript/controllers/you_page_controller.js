import { Controller } from "@hotwired/stimulus"

// You: inline name edit.
export default class extends Controller {
  static targets = [
    "nameButton",
    "nameForm",
    "nameInput",
    "version"
  ]

  connect() {
    this.syncVersion()
    if (this.element.dataset.youPageOpen === "name") this.editName()
  }

  syncVersion() {
    if (!this.hasVersionTarget) return

    const meta = document.querySelector('meta[name="app-version"]')
    this.versionTarget.textContent = meta?.content || "dev"
  }

  editName(event) {
    event?.preventDefault()
    if (!this.hasNameFormTarget || !this.hasNameButtonTarget) return
    this.nameButtonTarget.hidden = true
    this.nameFormTarget.hidden = false
    this.nameInputTarget?.focus()
    this.nameInputTarget?.select()
  }

  nameKey(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.cancelName()
    }
  }

  cancelName() {
    if (!this.hasNameFormTarget || !this.hasNameButtonTarget) return
    this.nameFormTarget.hidden = true
    this.nameButtonTarget.hidden = false
  }
}
