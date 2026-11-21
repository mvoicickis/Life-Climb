import { Controller } from "@hotwired/stimulus"

// Photo Today — inline add row. Collapsed label expands to field + ADD.
export default class extends Controller {
  static targets = ["field", "submit", "fail", "expand", "composer"]
  static values = {
    url: String,
    notSaved: { type: String, default: "Not saved. Tap to try again." },
    allClear: { type: Boolean, default: false }
  }

  connect() {
    this.saving = false
    if (this.hasFieldTarget) {
      this.grow()
      this.sync()
    }
  }

  expand(event) {
    event?.preventDefault()
    if (this.hasExpandTarget) this.expandTarget.hidden = true
    if (this.hasComposerTarget) {
      this.composerTarget.hidden = false
      this.composerTarget.removeAttribute("hidden")
    }
    window.requestAnimationFrame(() => {
      this.fieldTarget?.focus()
      this.grow()
      this.sync()
    })
  }

  sync() {
    if (!this.hasFieldTarget || !this.hasSubmitTarget) return
    const hasText = this.fieldTarget.value.trim().length > 0
    const ready = hasText || this.allClearValue
    const disabled = this.saving || (!hasText && !this.allClearValue)
    this.submitTarget.classList.toggle("is-ready", ready)
    this.submitTarget.classList.toggle("is-muted", !ready)
    this.submitTarget.disabled = disabled
    this.grow()
  }

  grow() {
    if (!this.hasFieldTarget) return
    const field = this.fieldTarget
    field.style.height = "auto"
    const max = parseFloat(getComputedStyle(field).maxHeight) || 140
    field.style.height = `${Math.min(field.scrollHeight, max)}px`
  }

  keydown(event) {
    if (event.key !== "Enter" || event.shiftKey) return
    event.preventDefault()
    this.save()
  }

  retry(event) {
    event.preventDefault()
    this.save()
  }

  async save() {
    if (this.saving) return
    if (!this.hasFieldTarget) return

    const title = this.fieldTarget.value.trim()
    if (!title) {
      this.fieldTarget.focus()
      return
    }

    this.saving = true
    this.hideFail()
    this.sync()

    const token = document.querySelector("meta[name='csrf-token']")?.content
    const body = new URLSearchParams()
    body.set("title", title)
    body.set("authenticity_token", token || "")

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          Accept: "text/vnd.turbo-stream.html, text/html",
          "X-CSRF-Token": token || ""
        },
        body,
        credentials: "same-origin"
      })

      if (!response.ok) throw new Error("not_ok")

      const contentType = response.headers.get("content-type") || ""
      const html = await response.text()
      if (contentType.includes("turbo-stream") && window.Turbo?.renderStreamMessage) {
        window.Turbo.renderStreamMessage(html)
      }

      window.requestAnimationFrame(() => {
        const host = document.querySelector("#today-battlefield-add-host [data-controller~='today-add-battle']")
        const expandBtn = host?.querySelector("[data-today-add-battle-target='expand']")
        expandBtn?.click()
      })
    } catch (_err) {
      this.showFail()
      this.fieldTarget.focus()
    } finally {
      this.saving = false
      if (this.hasSubmitTarget) this.sync()
    }
  }

  showFail() {
    if (!this.hasFailTarget) return
    this.failTarget.hidden = false
    this.failTarget.removeAttribute("hidden")
  }

  hideFail() {
    if (!this.hasFailTarget) return
    this.failTarget.hidden = true
    this.failTarget.setAttribute("hidden", "")
  }
}
