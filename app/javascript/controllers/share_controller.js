import { Controller } from "@hotwired/stimulus"

// Native share sheet, or copy message + landing URL to clipboard.
export default class extends Controller {
  static values = {
    text: String,
    url: String
  }

  async share(event) {
    event.preventDefault()
    event.stopPropagation()

    const text = this.textValue
    const url = this.urlValue
    const payload = `${text}\n${url}`

    if (navigator.share) {
      try {
        await navigator.share({ title: "LifePoints", text, url })
        return
      } catch (error) {
        if (error?.name === "AbortError") return
      }
    }

    try {
      await navigator.clipboard.writeText(payload)
      this.flashCopied(event.currentTarget)
    } catch (_error) {
      window.prompt("Copy this and share it:", payload)
    }
  }

  flashCopied(button) {
    if (!button) return
    const original = button.textContent
    button.textContent = "Copied!"
    button.disabled = true
    window.setTimeout(() => {
      button.textContent = original
      button.disabled = false
    }, 1600)
  }
}
