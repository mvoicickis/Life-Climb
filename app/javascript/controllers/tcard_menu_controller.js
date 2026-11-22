import { Controller } from "@hotwired/stimulus"
import { afterExitMotion, todaySheetExitEnabled } from "lib/lp_today_sheet_dismiss"

const OPEN_EVENT = "lp-tcard-menu:open"

// Minimal details/summary menu: Escape, outside click, one open at a time.
export default class extends Controller {
  static targets = ["details", "sheet", "scrim"]
  static values = { portal: Boolean }

  connect() {
    this._onPointer = (event) => this.onPointerDown(event)
    this._onKey = (event) => this.onKeydown(event)
    this._onOpenElsewhere = (event) => this.onOpenElsewhere(event)
    this._onReposition = () => this.positionMenu()
    window.addEventListener(OPEN_EVENT, this._onOpenElsewhere)
    if (this.hasDetailsTarget) {
      this._onDetailsToggle = () => this.toggled()
      this.detailsTarget.addEventListener("toggle", this._onDetailsToggle)
      this.syncPortalLayerVisibility()
    }
  }

  disconnect() {
    if (this.hasDetailsTarget && this._onDetailsToggle) {
      this.detailsTarget.removeEventListener("toggle", this._onDetailsToggle)
    }
    this._closing = false
    this.finishClose()
    window.removeEventListener(OPEN_EVENT, this._onOpenElsewhere)
  }

  toggled() {
    if (!this.hasDetailsTarget) return
    if (this.detailsTarget.open) {
      window.dispatchEvent(new CustomEvent(OPEN_EVENT, { detail: { source: this } }))
      this.openLayers()
      requestAnimationFrame(() => this.bindDocument())
      this.positionMenu()
      this.addRepositionListeners()
    } else if (this._closing) {
      // Animated close in progress; teardown runs once in finishClose.
    } else if (this.layersVisible() && this.shouldAnimateClose()) {
      this.beginExitAnimation()
    } else if (this.layersVisible()) {
      this.finishClose()
    } else {
      this.clearOpenListeners()
    }
  }

  close(event) {
    event?.preventDefault?.()
    if (!this.hasDetailsTarget) return
    if (this._closing) return
    this.closeAnimated()
  }

  // Sync teardown for sheet handoff (e.g. log → Edit). No exit motion.
  closeImmediate() {
    if (!this.hasDetailsTarget) return
    this._closing = false
    this.finishClose()
  }

  closeAnimated() {
    if (!this.hasDetailsTarget) return
    if (this._closing) return
    if (!this.detailsTarget.open && !this.layersVisible()) return

    if (!this.shouldAnimateClose()) {
      this.finishClose()
      return
    }

    this.beginExitAnimation()
  }

  beginExitAnimation() {
    if (this._closing) return
    this._closing = true
    this.unbindDocument()

    for (const element of this.visibleLayerElements()) {
      element.classList.remove("is-sheet-open")
      element.classList.add("is-sheet-closing")
    }

    const sheet = this.sheetLayer()
    const scrim = this.scrimLayer()
    this._exitGeneration = (this._exitGeneration || 0) + 1
    const generation = this._exitGeneration
    afterExitMotion([scrim, sheet], () => {
      if (generation !== this._exitGeneration) return
      this.finishClose()
    })
  }

  finishClose() {
    this._closing = false
    this._exitGeneration = (this._exitGeneration || 0) + 1

    for (const element of this.sheetLayerElements()) {
      element.hidden = true
      element.classList.remove("is-sheet-open", "is-sheet-closing")
    }

    this.restoreFromPortal()
    this.clearOpenListeners()

    if (this.hasDetailsTarget && this.detailsTarget.open) {
      this.detailsTarget.open = false
    }
  }

  shouldAnimateClose() {
    if (!todaySheetExitEnabled()) return false
    if (!this.portalValue) return false
    return this.visibleLayerElements().length > 0
  }

  layersVisible() {
    return this.sheetLayerElements().some((el) => !el.hidden)
  }

  visibleLayerElements() {
    return this.sheetLayerElements().filter((el) => !el.hidden)
  }

  addRepositionListeners() {
    window.addEventListener("resize", this._onReposition)
    window.visualViewport?.addEventListener("resize", this._onReposition)
    window.visualViewport?.addEventListener("scroll", this._onReposition)
  }

  clearOpenListeners() {
    this.unbindDocument()
    window.removeEventListener("resize", this._onReposition)
    window.visualViewport?.removeEventListener("resize", this._onReposition)
    window.visualViewport?.removeEventListener("scroll", this._onReposition)
  }

  positionMenu() {
    if (!this.hasDetailsTarget || !this.detailsTarget.open) return

    const summary = this.detailsTarget.querySelector("summary")
    const menu = this.detailsTarget.querySelector(".lp-trail-battles__kebab-menu")
    if (!summary || !menu) return

    const rect = summary.getBoundingClientRect()
    menu.style.position = "fixed"
    menu.style.top = `${Math.round(rect.bottom + 4)}px`
    menu.style.left = "auto"
    menu.style.right = `${Math.round(window.innerWidth - rect.right)}px`
    menu.style.zIndex = "120"

    requestAnimationFrame(() => {
      const menuRect = menu.getBoundingClientRect()
      if (menuRect.bottom > window.innerHeight - 8) {
        menu.style.top = `${Math.round(rect.top - menuRect.height - 4)}px`
      }
      if (menuRect.left < 8) {
        menu.style.right = "auto"
        menu.style.left = "8px"
      }
    })
  }

  onOpenElsewhere(event) {
    if (event.detail?.source === this) return
    this.close()
  }

  onPointerDown(event) {
    if (!this.hasDetailsTarget || !this.detailsTarget.open) return
    if (this.detailsTarget.contains(event.target)) return
    if (this.pointerOnScrim(event.target)) {
      this.close()
      return
    }
    if (this.layerContains(event.target)) return
    this.close()
  }

  pointerOnScrim(target) {
    const scrim = this.scrimLayer()
    const sheet = this.sheetLayer()
    if (!scrim || !target) return false
    if (sheet?.contains(target)) return false
    return target === scrim || scrim.contains(target)
  }

  scrimLayer() {
    for (const element of this._portaled || []) {
      if (element.getAttribute("data-tcard-menu-target") === "scrim") return element
    }
    return this.hasScrimTarget ? this.scrimTarget : null
  }

  sheetLayer() {
    for (const element of this._portaled || []) {
      if (element.getAttribute("data-tcard-menu-target") === "sheet") return element
    }
    return this.hasSheetTarget ? this.sheetTarget : null
  }

  layerContains(target) {
    if (!target) return false
    return this.sheetLayerElements().some((element) => element.contains(target))
  }

  onKeydown(event) {
    if (event.key !== "Escape") return
    if (!this.hasDetailsTarget || !this.detailsTarget.open) return
    this.close()
  }

  bindDocument() {
    document.addEventListener("pointerdown", this._onPointer, true)
    document.addEventListener("keydown", this._onKey, true)
  }

  unbindDocument() {
    document.removeEventListener("pointerdown", this._onPointer, true)
    document.removeEventListener("keydown", this._onKey, true)
  }

  portalToBody() {
    if (!this.portalValue) return
    if (!this._portaled) this._portaled = []

    for (const element of this.sheetLayerElements()) {
      if (!element._portalHome) {
        element._portalHome = { parent: element.parentNode, next: element.nextSibling }
      }
      document.body.appendChild(element)
      if (!this._portaled.includes(element)) this._portaled.push(element)
    }
  }

  restoreFromPortal() {
    if (!this.portalValue) return

    for (const element of this._portaled || []) {
      const home = element._portalHome
      if (!home?.parent) continue
      home.parent.insertBefore(element, home.next)
    }
    this._portaled = []
  }

  hasNamedTarget(name) {
    const method = `has${name.charAt(0).toUpperCase()}${name.slice(1)}Target`
    return typeof this[method] === "function" && this[method]()
  }

  // Portal while hidden, then unhide + is-sheet-open in the same turn (no rest-pose flash).
  openLayers() {
    this.portalToBody()
    for (const element of this.sheetLayerElements()) {
      element.classList.remove("is-sheet-closing")
      element.hidden = false
      element.classList.add("is-sheet-open")
    }
  }

  // This controller's Stimulus targets only (works inside or beside <details>).
  // Never query this.element — nested tcard-menu hosts must keep their own layers.
  sheetLayerElements() {
    const seen = new Set()
    const out = []
    const push = (el) => {
      if (!el || seen.has(el)) return
      seen.add(el)
      out.push(el)
    }

    if (this.hasScrimTarget) push(this.scrimTarget)
    if (this.hasSheetTarget) push(this.sheetTarget)

    for (const el of this._portaled || []) {
      const name = el.getAttribute("data-tcard-menu-target")
      if (name === "scrim" || name === "sheet") push(el)
    }

    return out
  }

  syncPortalLayerVisibility() {
    if (!this.hasDetailsTarget) return
    if (this.detailsTarget.open) {
      this.openLayers()
    } else {
      for (const element of this.sheetLayerElements()) {
        element.hidden = true
        element.classList.remove("is-sheet-open", "is-sheet-closing")
      }
    }
  }
}
