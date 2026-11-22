import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "drop", "preview" ]

  openPicker() {
    this.inputTarget.click()
  }

  dragOver(event) {
    event.preventDefault()
    this.dropTarget.classList.add("is-dragover")
  }

  dragLeave() {
    this.dropTarget.classList.remove("is-dragover")
  }

  drop(event) {
    event.preventDefault()
    this.dropTarget.classList.remove("is-dragover")
    const file = event.dataTransfer?.files?.[0]
    if (!file) return

    const transfer = new DataTransfer()
    transfer.items.add(file)
    this.inputTarget.files = transfer.files
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  picked() {
    this.dispatch("changed", { bubbles: true })
  }
}
