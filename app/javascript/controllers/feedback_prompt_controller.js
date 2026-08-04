import { Controller } from "@hotwired/stimulus"

// Dismissible testing-phase feedback prompt (no frequency cap — shows every visit).
export default class extends Controller {
  static targets = ["form", "body"]
  static values = { page: String }

  dismiss() {
    this.element.hidden = true
  }
}
