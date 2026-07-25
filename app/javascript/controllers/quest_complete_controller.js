import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  pop(event) {
    const row = event.currentTarget.closest(".studio-quest")
    if (!row) return
    row.classList.add("is-popping")
  }
}
