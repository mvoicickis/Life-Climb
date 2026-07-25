import { Controller } from "@hotwired/stimulus"

// Accessible profile / account dropdown with a solid floating card + page overlay.
export default class extends Controller {
  static targets = ["menu", "button", "backdrop"]

  connect() {
    this.boundPointer = this.onPointerDown.bind(this)
    this.boundKey = this.onKeydown.bind(this)
    this.boundReposition = this.positionMenu.bind(this)
  }

  disconnect() {
    this.close()
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    if (this.menuTarget.hidden) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.hidden = false
    if (this.hasBackdropTarget) this.backdropTarget.hidden = false

    document.body.append(this.backdropTarget, this.menuTarget)
    this.positionMenu()

    this.buttonTarget.setAttribute("aria-expanded", "true")
    document.body.classList.add("app-menu-open")
    this.element.classList.add("is-open")

    document.addEventListener("pointerdown", this.boundPointer)
    document.addEventListener("keydown", this.boundKey)
    window.addEventListener("resize", this.boundReposition)
    window.addEventListener("scroll", this.boundReposition, true)
  }

  close(event) {
    event?.preventDefault?.()
    if (!this.hasMenuTarget) return

    this.menuTarget.hidden = true
    if (this.hasBackdropTarget) this.backdropTarget.hidden = true

    this.element.append(this.menuTarget)
    if (this.hasBackdropTarget) this.element.append(this.backdropTarget)

    this.menuTarget.style.top = ""
    this.menuTarget.style.right = ""
    this.menuTarget.style.left = ""
    this.menuTarget.style.width = ""
    this.menuTarget.style.position = ""
    this.menuTarget.style.zIndex = ""

    this.buttonTarget?.setAttribute("aria-expanded", "false")
    document.body.classList.remove("app-menu-open")
    this.element.classList.remove("is-open")

    document.removeEventListener("pointerdown", this.boundPointer)
    document.removeEventListener("keydown", this.boundKey)
    window.removeEventListener("resize", this.boundReposition)
    window.removeEventListener("scroll", this.boundReposition, true)
  }

  positionMenu() {
    if (!this.hasMenuTarget || this.menuTarget.hidden) return

    const rect = this.buttonTarget.getBoundingClientRect()
    const gutter = 8
    const maxWidth = Math.min(296, window.innerWidth - gutter * 2)
    const right = Math.max(gutter, window.innerWidth - rect.right)
    const top = Math.min(rect.bottom + gutter, window.innerHeight - gutter)

    this.menuTarget.style.position = "fixed"
    this.menuTarget.style.top = `${top}px`
    this.menuTarget.style.right = `${right}px`
    this.menuTarget.style.left = "auto"
    this.menuTarget.style.width = `${maxWidth}px`
    this.menuTarget.style.zIndex = "100"
  }

  onPointerDown(event) {
    if (this.element.contains(event.target)) return
    if (this.hasMenuTarget && this.menuTarget.contains(event.target)) return
    if (this.hasBackdropTarget && event.target === this.backdropTarget) {
      this.close()
      return
    }
    this.close()
  }

  onKeydown(event) {
    if (event.key === "Escape") this.close()
  }
}
