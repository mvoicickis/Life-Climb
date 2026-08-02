import { Controller } from "@hotwired/stimulus"

// Practice quest folder — focus the Add Task field from the finish prompt.
export default class extends Controller {
  static targets = ["title"]

  addMore(event) {
    event?.preventDefault()
    this.element.open = true
    const input = this.hasTitleTarget ? this.titleTarget : this.element.querySelector("input[name='title']")
    if (!input) return
    input.focus()
    input.scrollIntoView({ block: "nearest", inline: "nearest" })
  }
}
