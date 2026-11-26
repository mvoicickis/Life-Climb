import { Controller } from "@hotwired/stimulus"

// Photo Today goal card — collapse the "Your goal" kicker after a short scroll.
// Collapsed preference lives on .lp-today-scroll__pad so stream-replaced cards
// reconnect without flashing the expanded height.
const COLLAPSE_AT = 24
const EXPAND_AT = 8
const COLLAPSED_CLASS = "is-collapsed"
const NO_TRANSITION_CLASS = "is-no-transition"
const PAD_FLAG = "goalCardCollapsed"

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
    // Instant apply from pad flag / scrollTop — no 180ms expand flash after turbo replace.
    this.setCollapsed(this.readCollapsedPreference(), { silent: true })
  }

  disconnect() {
    if (this.frame != null) {
      window.cancelAnimationFrame(this.frame)
      this.frame = null
    }
    if (this.enableFrame != null) {
      window.cancelAnimationFrame(this.enableFrame)
      this.enableFrame = null
    }
    if (this.pad && this.onScroll) {
      this.pad.removeEventListener("scroll", this.onScroll)
    }
    this.pad = null
    this.onScroll = null
  }

  syncCollapsed() {
    if (!this.pad) return
    this.setCollapsed(this.wantsCollapsed(), { silent: false })
  }

  wantsCollapsed() {
    const scrollTop = this.pad.scrollTop
    if (this.element.classList.contains(COLLAPSED_CLASS)) {
      return scrollTop > EXPAND_AT
    }
    return scrollTop > COLLAPSE_AT
  }

  readCollapsedPreference() {
    const flag = this.pad.dataset[PAD_FLAG]
    const scrollTop = this.pad.scrollTop
    if (flag === "true") return scrollTop > EXPAND_AT
    if (flag === "false") return scrollTop > COLLAPSE_AT
    return scrollTop > COLLAPSE_AT
  }

  setCollapsed(collapsed, { silent = false } = {}) {
    if (this.element.classList.contains(COLLAPSED_CLASS) === collapsed) return
    this.pad.dataset[PAD_FLAG] = collapsed ? "true" : "false"
    if (silent) {
      this.element.classList.add(NO_TRANSITION_CLASS)
      this.element.classList.toggle(COLLAPSED_CLASS, collapsed)
      this.queueEnableTransitions()
      return
    }
    this.element.classList.toggle(COLLAPSED_CLASS, collapsed)
  }

  queueEnableTransitions() {
    if (this.enableFrame != null) window.cancelAnimationFrame(this.enableFrame)
    this.enableFrame = window.requestAnimationFrame(() => {
      this.enableFrame = window.requestAnimationFrame(() => {
        this.enableFrame = null
        this.element.classList.remove(NO_TRANSITION_CLASS)
      })
    })
  }
}
