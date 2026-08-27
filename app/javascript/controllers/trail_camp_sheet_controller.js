import { Controller } from "@hotwired/stimulus"

// Bottom battle sheet for a trail camp marker.
// Android back closes the sheet (history.pushState) instead of leaving Mountain.
export default class extends Controller {
  static targets = ["sheet", "panel", "title", "body", "accent"]

  connect() {
    this._onKey = (event) => this.onKeydown(event)
    this._onPopState = () => this.onPopState()
    this._openCampId = null
    this._pushedHistory = false
    this._closingViaHistory = false
    window.addEventListener("popstate", this._onPopState)
  }

  disconnect() {
    window.removeEventListener("popstate", this._onPopState)
    this.teardown({ skipHistory: true })
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

  openBase(event) {
    if (this.element.classList.contains("is-placing")) return
    if (this.element.classList.contains("is-relocating")) return

    event?.preventDefault()
    event?.stopPropagation()
    if (!this.hasSheetTarget) return

    const alreadyOpen = this.sheetTarget.classList.contains("is-open") && !this.sheetTarget.hidden
    const accent = "#d8892a"
    this.element.style.setProperty("--lp-trail-accent", accent)
    if (this.hasPanelTarget) this.panelTarget.style.setProperty("--lp-trail-accent", accent)
    if (this.hasAccentTarget) {
      this.accentTarget.style.setProperty("--lp-trail-accent", accent)
      this.accentTarget.dataset.accent = accent
    }
    if (this.hasTitleTarget) this.titleTarget.textContent = this.baseTitle()

    this.revealBodyFor({ dataset: { campId: "base" } })
    this._openCampId = "base"
    this.sheetTarget.hidden = false
    this.sheetTarget.classList.add("is-open")
    this.sheetTarget.setAttribute("aria-hidden", "false")
    document.addEventListener("keydown", this._onKey)
    if (!alreadyOpen) this.pushSheetHistory()
  }

  baseTitle() {
    return this.element.querySelector(".lp-trail-base-card__kicker")?.textContent?.trim() || "Base camp"
  }

  open(event) {
    if (event?.defaultPrevented) return
    if (this.element.dataset.trailSuppressOpen === "1") return
    if (this.element.classList.contains("is-placing")) return
    if (this.element.classList.contains("is-relocating")) return

    event?.preventDefault()
    event?.stopPropagation()

    const camp = event?.currentTarget
    if (!camp || !this.hasSheetTarget) return

    const alreadyOpen = this.sheetTarget.classList.contains("is-open") && !this.sheetTarget.hidden

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

    if (!alreadyOpen) this.pushSheetHistory()

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

  onPopState() {
    if (this._closingViaHistory) {
      this._closingViaHistory = false
      return
    }
    if (!this._pushedHistory) return
    this._pushedHistory = false
    this.teardown({ skipHistory: true })
  }

  pushSheetHistory() {
    if (this._pushedHistory) return
    history.pushState({ lpTrailCampSheet: this._openCampId || true }, "", window.location.href)
    this._pushedHistory = true
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

  teardown({ skipHistory = false } = {}) {
    document.removeEventListener("keydown", this._onKey)
    if (!this.hasSheetTarget) return

    this.sheetTarget.classList.remove("is-open")
    this.sheetTarget.setAttribute("aria-hidden", "true")
    this.sheetTarget.hidden = true
    this._openCampId = null

    if (!skipHistory && this._pushedHistory) {
      this._pushedHistory = false
      this._closingViaHistory = true
      history.back()
    }
  }
}
