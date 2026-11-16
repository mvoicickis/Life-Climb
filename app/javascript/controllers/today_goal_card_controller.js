import { Controller } from "@hotwired/stimulus"

// Photo Today goal card — collapse the "Your goal" kicker after a short scroll.
const COLLAPSE_AT = 24
const COLLAPSED_CLASS = "is-collapsed"

export default class extends Controller {
  connect() {
    this.pad = this.element.closest(".lp-today-scroll__pad")
    if (!this.pad) return

    this.onScroll = () => {
      if (this.frame != null) return
      this.frame = window.requestAnimationFrame(() => {
        this.frame = null
        this.syncCollapsed()
      })
    }

    this.pad.addEventListener("scroll", this.onScroll, { passive: true })
    this.syncCollapsed()
  }

  disconnect() {
    if (this.frame != null) {
      window.cancelAnimationFrame(this.frame)
      this.frame = null
    }
    if (this.pad && this.onScroll) {
      this.pad.removeEventListener("scroll", this.onScroll)
    }
    this.pad = null
    this.onScroll = null
  }

  syncCollapsed() {
    if (!this.pad) return
    this.element.classList.toggle(COLLAPSED_CLASS, this.pad.scrollTop > COLLAPSE_AT)
  }
}
