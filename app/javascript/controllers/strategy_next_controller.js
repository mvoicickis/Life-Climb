import { Controller } from "@hotwired/stimulus"

// Fill example chips + reveal "add another battle" under the handoff CTA.
export default class extends Controller {
  static targets = ["addForm", "addToggle"]

  fillExample(event) {
    const title = event.currentTarget.dataset.title
    const input = this.element.querySelector("#next-up-title") || this.element.querySelector("#add-battle-title")
    if (input && title) {
      input.value = title
      input.focus()
    }
  }

  showAddBattle(event) {
    event.preventDefault()
    if (!this.hasAddFormTarget) return

    this.addFormTarget.hidden = false
    this.addFormTarget.classList.add("is-open")
    if (this.hasAddToggleTarget) this.addToggleTarget.hidden = true

    const input = this.addFormTarget.querySelector("#add-battle-title, input[name='title']")
    input?.focus()
    this.addFormTarget.scrollIntoView({ block: "center", behavior: "smooth" })
  }
}
