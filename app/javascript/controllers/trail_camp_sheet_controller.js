import { Controller } from "@hotwired/stimulus"

// Bottom battle sheet for a trail camp marker.
// Android back closes the sheet (history.pushState) instead of leaving Mountain.
export default class extends Controller {
  static targets = ["sheet", "panel", "title", "subtitle", "body", "accent"]

  static values = {
    baseTitleFallback: String
  }

  connect() {
    this._onKey = (event) => this.onKeydown(event)
    this._onPopState = () => this.onPopState()
    this._openCampId = null
    this._pushedHistory = false
    window.addEventListener("popstate", this._onPopState)
  }

  disconnect() {
    window.removeEventListener("popstate", this._onPopState)
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
    this.setSubtitle("")

    this.revealBodyFor({ dataset: { campId: "base" } })
    this._openCampId = "base"
    this.hideCampMenus()
    this.sheetTarget.hidden = false
    this.sheetTarget.classList.add("is-open")
    this.sheetTarget.setAttribute("aria-hidden", "false")
    document.addEventListener("keydown", this._onKey)
    if (!alreadyOpen) this.pushSheetHistory()
  }

  baseTitle() {
    const card = this.element.querySelector(".lp-trail-base-card")
    return card?.dataset.baseTitle?.trim() || this.baseTitleFallbackValue || ""
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
    this.setSubtitle(camp.dataset.campDescription || "")

    this.revealBodyFor(camp)
    this._openCampId = camp.dataset.campId || null
    this.showCampMenu(this._openCampId)

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
    if (!this._pushedHistory) return
    this.teardown()
  }

  pushSheetHistory() {
    if (this._pushedHistory) return
    history.pushState({ lpTrailCampSheet: this._openCampId || true }, "", window.location.href)
    this._pushedHistory = true
  }

  stop(event) {
    event.stopPropagation()
  }

  editCamp(event) {
    event?.preventDefault()
    event?.stopPropagation()
    this.activeTrailBattlesController()?.editCamp(event)
  }

  editCampDescription(event) {
    event?.preventDefault()
    event?.stopPropagation()
    this.activeTrailBattlesController()?.editCampDescription(event)
  }

  showCampMenu(campId) {
    if (!this.hasSheetTarget || !campId) return this.hideCampMenus()

    this.sheetTarget.querySelectorAll("[data-camp-menu-panel]").forEach((menu) => {
      const match = menu.dataset.campMenuPanel === String(campId)
      menu.hidden = !match
      menu.toggleAttribute("hidden", !match)
    })
  }

  hideCampMenus() {
    if (!this.hasSheetTarget) return

    this.sheetTarget.querySelectorAll("[data-camp-menu-panel]").forEach((menu) => {
      menu.hidden = true
      menu.setAttribute("hidden", "")
      const controller = this.application.getControllerForElementAndIdentifier(menu, "plan-card-menu")
      controller?.close()
    })
  }

  activeTrailBattlesController() {
    if (!this._openCampId || !this.hasBodyTarget) return null

    const panel = this.bodyTarget.querySelector(`[data-camp-panel="${this._openCampId}"]:not([hidden])`)
    const root = panel?.querySelector("[data-controller~='trail-battles']")
    if (!root) return null

    return this.application.getControllerForElementAndIdentifier(root, "trail-battles")
  }

  setSubtitle(text) {
    if (!this.hasSubtitleTarget) return

    const copy = text.trim()
    if (copy) {
      this.subtitleTarget.textContent = copy
      this.subtitleTarget.hidden = false
      this.subtitleTarget.removeAttribute("hidden")
    } else {
      this.subtitleTarget.textContent = ""
      this.subtitleTarget.hidden = true
      this.subtitleTarget.setAttribute("hidden", "")
    }
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

    this.hideCampMenus()
    this.sheetTarget.classList.remove("is-open")
    this.sheetTarget.setAttribute("aria-hidden", "true")
    this.sheetTarget.hidden = true
    this._openCampId = null
    this._pushedHistory = false
  }
}
