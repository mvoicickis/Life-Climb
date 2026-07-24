import { Controller } from "@hotwired/stimulus"

// Native share sheet, or in-card copy fallback.
export default class extends Controller {
  static targets = ["fallback"]
  static values = {
    text: String,
    url: String
  }

  async share(event) {
    event.preventDefault()
    event.stopPropagation()

    const text = this.textValue
    const url = this.urlValue
    const payload = `${text}\n\nTry it:\n${url}`

    if (navigator.share) {
      try {
        await navigator.share({ title: "LifePoints", text: payload, url })
        return
      } catch (error) {
        if (error?.name === "AbortError") return
      }
    }

    this.showFallback()
  }

  showFallback() {
    if (!this.hasFallbackTarget) return
    this.fallbackTarget.hidden = false
  }

  async copyMessage(event) {
    event.preventDefault()
    event.stopPropagation()
    const payload = `${this.textValue}\n\nTry it:\n${this.urlValue}`
    await this.copy(payload, event.currentTarget, "Copied message")
  }

  async copyLink(event) {
    event.preventDefault()
    event.stopPropagation()
    await this.copy(this.urlValue, event.currentTarget, "Copied link")
  }

  async copy(text, button, doneLabel) {
    try {
      await navigator.clipboard.writeText(text)
      this.flash(button, doneLabel)
    } catch (_error) {
      window.prompt("Copy this:", text)
    }
  }

  flash(button, label) {
    if (!button) return
    const original = button.textContent
    button.textContent = label
    button.disabled = true
    window.setTimeout(() => {
      button.textContent = original
      button.disabled = false
    }, 1600)
  }
}
