import { Controller } from "@hotwired/stimulus"

// Dismissible climb reward ceremony.
export default class extends Controller {
  static values = { auto: Boolean }

  connect() {
    if (this.autoValue && typeof this.element.showModal === "function" && !this.element.open) {
      this.element.showModal()
    }
  }

  dismiss(event) {
    // Allow navigation links to proceed; just close the dialog chrome.
    if (this.element.open) this.element.close()
    if (event?.currentTarget?.tagName === "BUTTON") {
      event.preventDefault()
    }
  }
}
