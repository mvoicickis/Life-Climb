import { Controller } from "@hotwired/stimulus"

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
    this.restoreFromPortal()
    this.unbindDocument()
    window.removeEventListener(OPEN_EVENT, this._onOpenElsewhere)
  }

  toggled() {
    if (!this.hasDetailsTarget) return
    if (this.detailsTarget.open) {
      window.dispatchEvent(new CustomEvent(OPEN_EVENT, { detail: { source: this } }))
      this.setPortalLayersVisible(true)
      this.portalToBody()
      requestAnimationFrame(() => this.bindDocument())
      this.positionMenu()
      window.addEventListener("resize", this._onReposition)
      window.visualViewport?.addEventListener("resize", this._onReposition)
      window.visualViewport?.addEventListener("scroll", this._onReposition)
    } else {
      this.setPortalLayersVisible(false)
      this.restoreFromPortal()
      this.unbindDocument()
      window.removeEventListener("resize", this._onReposition)
      window.visualViewport?.removeEventListener("resize", this._onReposition)
      window.visualViewport?.removeEventListener("scroll", this._onReposition)
    }
  }

  close(event) {
    event?.preventDefault?.()
    if (!this.hasDetailsTarget) return
    this.detailsTarget.open = false
    this.setPortalLayersVisible(false)
    this.restoreFromPortal()
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
    return this.element.querySelector('[data-tcard-menu-target="scrim"]')
  }

  sheetLayer() {
    for (const element of this._portaled || []) {
      if (element.getAttribute("data-tcard-menu-target") === "sheet") return element
    }
    return this.element.querySelector('[data-tcard-menu-target="sheet"]')
  }

  layerContains(target) {
    if (!target) return false
    for (const element of this._portaled || []) {
      if (element.contains(target)) return true
    }
    for (const selector of ['[data-tcard-menu-target="scrim"]', '[data-tcard-menu-target="sheet"]']) {
      const element = this.element.querySelector(selector)
      if (element?.contains(target)) return true
    }
    return false
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

    for (const selector of ['[data-tcard-menu-target="scrim"]', '[data-tcard-menu-target="sheet"]']) {
      const element = this.element.querySelector(selector)
      if (!element) continue

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

  setPortalLayersVisible(visible) {
    const elements = [
      ...this.element.querySelectorAll('[data-tcard-menu-target="scrim"], [data-tcard-menu-target="sheet"]'),
      ...(this._portaled || [])
    ]
    for (const element of elements) {
      element.hidden = !visible
    }
  }

  syncPortalLayerVisibility() {
    if (!this.hasDetailsTarget) return
    this.setPortalLayersVisible(this.detailsTarget.open)
  }
}
