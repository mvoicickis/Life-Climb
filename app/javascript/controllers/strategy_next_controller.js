import { Controller } from "@hotwired/stimulus"

// Fill example chips into the inline Next Up title field.
export default class extends Controller {
  fillExample(event) {
    const title = event.currentTarget.dataset.title
    const input = this.element.querySelector("#next-up-title")
    if (input && title) {
      input.value = title
      input.focus()
    }
  }
}
