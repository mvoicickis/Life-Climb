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
  }

  disconnect() {
    this.restoreFromPortal()
    this.unbindDocument()
    window.removeEventListener(OPEN_EVENT, this._onOpenElsewhere)
  }

  toggled() {
    if (!this.hasDetailsTarget) return
    if (this.detailsTarget.open) {
      window.dispatchEvent(new CustomEvent(OPEN_EVENT, { detail: { source: this } }))
      this.portalToBody()
      this.bindDocument()
      this.positionMenu()
      window.addEventListener("resize", this._onReposition)
      window.visualViewport?.addEventListener("resize", this._onReposition)
      window.visualViewport?.addEventListener("scroll", this._onReposition)
    } else {
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
    this.close()
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

    for (const target of ["scrim", "sheet"]) {
      if (!this.hasNamedTarget(target)) continue

      const element = this[`${target}Target`]
      if (!element._portalHome) {
        element._portalHome = { parent: element.parentNode, next: element.nextSibling }
      }
      document.body.appendChild(element)
    }
  }

  restoreFromPortal() {
    if (!this.portalValue) return

    for (const target of ["sheet", "scrim"]) {
      if (!this.hasNamedTarget(target)) continue

      const element = this[`${target}Target`]
      const home = element._portalHome
      if (!home?.parent) continue

      home.parent.insertBefore(element, home.next)
    }
  }

  hasNamedTarget(name) {
    const method = `has${name.charAt(0).toUpperCase()}${name.slice(1)}Target`
    return typeof this[method] === "function" && this[method]()
  }
}
