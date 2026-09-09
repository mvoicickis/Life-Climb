import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form",
    "titleField",
    "repeatField",
    "error"
  ]

  static values = {
    needTitle: String
  }

  titleKeydown(event) {
    if (event.key !== "Enter") return
    event.preventDefault()
    this.formTarget.requestSubmit()
  }

  submit(event) {
    if (this.formTarget.dataset.confirmed === "true") {
      this.formTarget.dataset.confirmed = "false"
      return
    }

    event.preventDefault()
    this.clearError()

    const title = this.titleFieldTarget.value.trim()
    if (!title) {
      this.showError(this.needTitleValue)
      return
    }

    this.formTarget.dataset.confirmed = "true"
    this.formTarget.requestSubmit()
  }

  saved(event) {
    if (!event.detail.success) return

    const reveal = this.application.getControllerForElementAndIdentifier(
      document.getElementById("mountain-trail"),
      "first-camp-reveal"
    )
    reveal?.finish()
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
    this.errorTarget.removeAttribute("hidden")
  }

  clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ""
    this.errorTarget.hidden = true
    this.errorTarget.setAttribute("hidden", "")
  }
}
