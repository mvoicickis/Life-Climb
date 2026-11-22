import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "button" ]
  static values = {
    emails: String,
    copied: { type: String, default: "Copied!" }
  }

  async copy(event) {
    event.preventDefault()
    const text = this.emailsValue
    if (!text) return

    const button = this.hasButtonTarget ? this.buttonTarget : event.currentTarget
    const defaultLabel = button.textContent

    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(text)
      } else {
        window.prompt("Copy these emails:", text)
        return
      }
    } catch (_error) {
      window.prompt("Copy these emails:", text)
      return
    }

    button.textContent = this.copiedValue
    window.clearTimeout(this.resetTimer)
    this.resetTimer = window.setTimeout(() => {
      button.textContent = defaultLabel
    }, 2000)
  }
}