import { Controller } from "@hotwired/stimulus"

const OPEN_EVENT = "lp-rpg-path-menu:open"

// Plan card ⋮ menu — UI only; edit/delete actions are wired later.
export default class extends Controller {
  static targets = ["button", "menu"]

  connect() {
    this.menuEl = this.menuTarget
    this.menuHome = this.menuEl.parentElement
    this._onPointer = (event) => this.onPointerDown(event)
    this._onKey = (event) => this.onKeydown(event)
    this._onOpenElsewhere = (event) => this.onOpenElsewhere(event)
    this._onReposition = () => this.positionMenu()
    window.addEventListener(OPEN_EVENT, this._onOpenElsewhere)
  }

  disconnect() {
    this.close()
    window.removeEventListener(OPEN_EVENT, this._onOpenElsewhere)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    if (this.menuEl.hidden) {
      this.open()
    } else {
      this.close()
    }
  }

  // Placeholder until edit/delete are implemented.
  noop(event) {
    event.preventDefault()
    event.stopPropagation()
    this.close()
  }

  open() {
    window.dispatchEvent(new CustomEvent(OPEN_EVENT, { detail: { source: this } }))
    if (this.menuEl.parentElement !== document.body) {
      document.body.appendChild(this.menuEl)
    }
    this.menuEl.hidden = false
    this.buttonTarget.setAttribute("aria-expanded", "true")
    this.element.classList.add("is-menu-open")
    this.positionMenu()
    document.addEventListener("pointerdown", this._onPointer)
    document.addEventListener("keydown", this._onKey)
    window.addEventListener("resize", this._onReposition)
    const track = this.element.closest(".lp-rpg-plan-rail__track")
    if (track) {
      this._track = track
      track.addEventListener("scroll", this._onReposition, { passive: true })
    }
  }

  close() {
    if (!this.menuEl) return
    this.menuEl.hidden = true
    if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-expanded", "false")
    this.element.classList.remove("is-menu-open")
    if (this.menuHome && this.menuEl.parentElement !== this.menuHome) {
      this.menuHome.appendChild(this.menuEl)
    }
    document.removeEventListener("pointerdown", this._onPointer)
    document.removeEventListener("keydown", this._onKey)
    window.removeEventListener("resize", this._onReposition)
    this._track?.removeEventListener("scroll", this._onReposition)
    this._track = null
  }

  positionMenu() {
    if (!this.menuEl || this.menuEl.hidden || !this.hasButtonTarget) return

    const rect = this.buttonTarget.getBoundingClientRect()
    const menu = this.menuEl
    menu.style.position = "fixed"
    menu.style.top = `${Math.round(rect.bottom + 4)}px`
    menu.style.left = "auto"
    menu.style.right = `${Math.round(window.innerWidth - rect.right)}px`
    menu.style.zIndex = "80"

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

  onPointerDown(event) {
    if (this.buttonTarget.contains(event.target) || this.menuEl.contains(event.target)) return
    this.close()
  }

  onKeydown(event) {
    if (event.key === "Escape") this.close()
  }

  onOpenElsewhere(event) {
    if (event.detail?.source !== this) this.close()
  }
}
