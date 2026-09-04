import { Controller } from "@hotwired/stimulus"
import { attachTitleLimit } from "lib/title_limit"

// Shows "200 of 200 letters used" when a title input hits maxlength.
export default class extends Controller {
  static targets = ["count"]
  static values = {
    atMaxTemplate: { type: String, default: "%{count} of %{max} letters used" }
  }

  connect() {
    this.input = this.element.querySelector("input[type='text'], textarea")
    if (!this.input) return

    if (this.hasCountTarget) {
      this.limit = attachTitleLimit(this.input, { template: this.atMaxTemplateValue })
    }
  }

  disconnect() {
    this.limit?.detach()
  }
}
