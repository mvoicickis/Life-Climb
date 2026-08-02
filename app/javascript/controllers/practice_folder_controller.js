import { Controller } from "@hotwired/stimulus"

// Practice quest folder — reveal inline Add Objective field.
export default class extends Controller {
  static targets = ["title", "reveal", "form", "addWrap"]

  connect() {
    this.hideAddForm()
  }

  addMore(event) {
    this.revealAdd(event)
  }

  revealAdd(event) {
    event?.preventDefault()
    this.element.open = true
    if (this.hasRevealTarget) this.revealTarget.hidden = true
    if (this.hasFormTarget) this.formTarget.hidden = false
    const input = this.hasTitleTarget ? this.titleTarget : this.element.querySelector("input[name='title']")
    if (!input) return
    requestAnimationFrame(() => {
      input.focus()
      input.scrollIntoView({ block: "nearest", inline: "nearest" })
    })
  }

  hideAddForm() {
    if (this.hasRevealTarget) this.revealTarget.hidden = false
    if (this.hasFormTarget) this.formTarget.hidden = true
  }
}
