import { Controller } from "@hotwired/stimulus"

// Accessible profile / account dropdown.
export default class extends Controller {
  static targets = ["menu", "button"]

  connect() {
    this.boundPointer = this.onPointerDown.bind(this)
    this.boundKey = this.onKeydown.bind(this)
  }

  disconnect() {
    this.close()
  }

  toggle(event) {
    event.preventDefault()
    if (this.menuTarget.hidden) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.hidden = false
    this.buttonTarget.setAttribute("aria-expanded", "true")
    document.addEventListener("pointerdown", this.boundPointer)
    document.addEventListener("keydown", this.boundKey)
  }

  close() {
    if (!this.hasMenuTarget) return
    this.menuTarget.hidden = true
    this.buttonTarget?.setAttribute("aria-expanded", "false")
    document.removeEventListener("pointerdown", this.boundPointer)
    document.removeEventListener("keydown", this.boundKey)
  }

  onPointerDown(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  onKeydown(event) {
    if (event.key === "Escape") this.close()
  }
}
