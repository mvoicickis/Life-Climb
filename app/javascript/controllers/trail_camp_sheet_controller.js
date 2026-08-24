import { Controller } from "@hotwired/stimulus"

// Bottom battle sheet for a trail camp marker.
export default class extends Controller {
  static targets = ["sheet", "panel", "title", "body", "accent"]

  connect() {
    this._onKey = (event) => this.onKeydown(event)
    this._openCampId = null
  }

  disconnect() {
    this.teardown()
  }

  open(event) {
    // Swallow if the canvas just finished a drag-reposition.
    if (event?.defaultPrevented) return
    if (this.element.dataset.trailSuppressOpen === "1") return

    event?.preventDefault()
    event?.stopPropagation()

    const camp = event?.currentTarget
    if (!camp || !this.hasSheetTarget) return

    const accent = camp.dataset.accent || camp.style.getPropertyValue("--lp-trail-accent") || "#0f766e"
    this.element.style.setProperty("--lp-trail-accent", accent)
    if (this.hasPanelTarget) this.panelTarget.style.setProperty("--lp-trail-accent", accent)
    if (this.hasAccentTarget) {
      this.accentTarget.style.color = accent
      this.accentTarget.dataset.accent = accent
    }

    const title = camp.dataset.campTitle || camp.getAttribute("aria-label") || camp.title || ""
    if (this.hasTitleTarget) this.titleTarget.textContent = title

    this.revealBodyFor(camp)
    this._openCampId = camp.dataset.campId || null

    this.sheetTarget.hidden = false
    this.sheetTarget.classList.add("is-open")
    this.sheetTarget.setAttribute("aria-hidden", "false")
    document.addEventListener("keydown", this._onKey)

    requestAnimationFrame(() => {
      const focusable = this.panelTarget?.querySelector(
        "button, [href], input, textarea, [tabindex]:not([tabindex='-1'])"
      )
      focusable?.focus({ preventScroll: true })
    })
  }

  close(event) {
    event?.preventDefault()
    event?.stopPropagation()
    this.teardown()
  }

  closeOnBackdrop(event) {
    if (event.target === event.currentTarget) this.close(event)
  }

  onKeydown(event) {
    if (event.key === "Escape") this.close(event)
  }

  stop(event) {
    event.stopPropagation()
  }

  revealBodyFor(camp) {
    if (!this.hasBodyTarget) return

    const campId = camp.dataset.campId
    const frame = this.bodyTarget.querySelector("turbo-frame")
    const src = camp.dataset.sheetSrc || camp.dataset.sheetUrl

    // Prefer per-camp static panels already in the DOM.
    const panels = this.bodyTarget.querySelectorAll("[data-camp-panel]")
    if (panels.length) {
      panels.forEach((panel) => {
        const match = panel.dataset.campPanel === String(campId)
        panel.hidden = !match
        panel.toggleAttribute("hidden", !match)
      })
      return
    }

    // Or a turbo-frame that loads camp detail.
    if (frame && src) {
      if (frame.getAttribute("src") !== src) frame.setAttribute("src", src)
      return
    }

    // Last resort: inline HTML from the marker.
    const html = camp.dataset.sheetHtml
    if (html) this.bodyTarget.innerHTML = html
  }

  teardown() {
    document.removeEventListener("keydown", this._onKey)
    if (!this.hasSheetTarget) return

    this.sheetTarget.classList.remove("is-open")
    this.sheetTarget.setAttribute("aria-hidden", "true")
    this.sheetTarget.hidden = true
    this._openCampId = null
  }
}
