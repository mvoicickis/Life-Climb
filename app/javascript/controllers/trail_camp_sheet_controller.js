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

  openFromDock(event) {
    const campId = event.currentTarget?.dataset?.campId
    const camp = campId && this.element.querySelector(`#trail-camp-${campId}`)
    if (!camp) return

    event.preventDefault()
    event.stopPropagation()
    this.open({
      currentTarget: camp,
      preventDefault() {},
      stopPropagation() {},
      defaultPrevented: false
    })
  }

  open(event) {
    if (event?.defaultPrevented) return
    if (this.element.dataset.trailSuppressOpen === "1") return
    if (this.element.classList.contains("is-placing")) return

    event?.preventDefault()
    event?.stopPropagation()

    const camp = event?.currentTarget
    if (!camp || !this.hasSheetTarget) return

    const accent = camp.dataset.accent || camp.style.getPropertyValue("--lp-trail-accent") || "#0f9488"
    this.element.style.setProperty("--lp-trail-accent", accent)
    if (this.hasPanelTarget) this.panelTarget.style.setProperty("--lp-trail-accent", accent)
    if (this.hasAccentTarget) {
      this.accentTarget.style.setProperty("--lp-trail-accent", accent)
      this.accentTarget.dataset.accent = accent
    }

    const title = camp.dataset.campTitle || camp.getAttribute("aria-label") || ""
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
    if (event.target === event.currentTarget || event.target.classList?.contains("lp-trail-sheet__backdrop")) {
      this.close(event)
    }
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
    const panels = this.bodyTarget.querySelectorAll("[data-camp-panel]")
    panels.forEach((panel) => {
      const match = panel.dataset.campPanel === String(campId)
      panel.hidden = !match
      panel.toggleAttribute("hidden", !match)
    })
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
