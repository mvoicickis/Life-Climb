import { Controller } from "@hotwired/stimulus"

// Photo Today goal card — collapse the "Your goal" kicker after a short scroll.
// Collapsed preference lives on .lp-today-scroll__pad so stream-replaced cards
// reconnect without flashing the expanded height.
//
// Collapse only when the pad still has scroll room after the height drop, and
// use thresholds wider than the measured height delta so scrollTop cannot
// bounce the class in a loop (short lists + scroll anchoring).
const EXPAND_AT = 4
const COLLAPSE_EXTRA = 16
const ROOM_SLACK = 40
const TRANSITION_LOCK_MS = 300
const COLLAPSED_CLASS = "is-collapsed"
const NO_TRANSITION_CLASS = "is-no-transition"
const PAD_FLAG = "goalCardCollapsed"

export default class extends Controller {
  connect() {
    this.pad = this.element.closest(".lp-today-scroll__pad")
    if (!this.pad) return

    this.collapsedDelta = null
    this.transitionLocked = false
    this.lockTimer = null
    this.onTransitionEnd = (event) => this.handleTransitionEnd(event)

    this.onScroll = () => {
      if (this.frame != null) return
      this.frame = window.requestAnimationFrame(() => {
        this.frame = null
        this.syncCollapsed()
      })
    }

    this.pad.addEventListener("scroll", this.onScroll, { passive: true })
    this.element.addEventListener("transitionend", this.onTransitionEnd)
    // Instant apply from pad flag / scrollTop — no expand flash after turbo replace.
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
    if (this.lockTimer != null) {
      window.clearTimeout(this.lockTimer)
      this.lockTimer = null
    }
    if (this.pad && this.onScroll) {
      this.pad.removeEventListener("scroll", this.onScroll)
    }
    if (this.onTransitionEnd) {
      this.element.removeEventListener("transitionend", this.onTransitionEnd)
    }
    this.pad = null
    this.onScroll = null
    this.onTransitionEnd = null
    this.transitionLocked = false
    this.collapsedDelta = null
  }

  syncCollapsed() {
    if (!this.pad) return
    if (this.transitionLocked) return
    this.setCollapsed(this.wantsCollapsed(), { silent: false })
  }

  wantsCollapsed() {
    const scrollTop = this.pad.scrollTop
    if (this.element.classList.contains(COLLAPSED_CLASS)) {
      return scrollTop > EXPAND_AT
    }
    if (!this.hasCollapseRoom()) return false
    return scrollTop > this.collapseAt()
  }

  readCollapsedPreference() {
    const flag = this.pad.dataset[PAD_FLAG]
    const scrollTop = this.pad.scrollTop
    if (!this.hasCollapseRoom()) return false
    if (flag === "true") return scrollTop > EXPAND_AT
    if (flag === "false") return scrollTop > this.collapseAt()
    return scrollTop > this.collapseAt()
  }

  collapseAt() {
    return this.ensureCollapsedDelta() + COLLAPSE_EXTRA
  }

  hasCollapseRoom() {
    const delta = this.ensureCollapsedDelta()
    const collapsedNow = this.element.classList.contains(COLLAPSED_CLASS)
    // When already collapsed, pad.scrollHeight is shorter by ~delta — restore it
    // so the room check matches the expanded layout the user would return to.
    const scrollHeight = this.pad.scrollHeight + (collapsedNow ? delta : 0)
    return scrollHeight - this.pad.clientHeight > delta + ROOM_SLACK
  }

  ensureCollapsedDelta() {
    if (this.collapsedDelta != null) return this.collapsedDelta

    const wasCollapsed = this.element.classList.contains(COLLAPSED_CLASS)
    this.element.classList.add(NO_TRANSITION_CLASS)
    this.element.classList.remove(COLLAPSED_CLASS)
    void this.element.offsetHeight
    const expanded = this.element.getBoundingClientRect().height

    this.element.classList.add(COLLAPSED_CLASS)
    void this.element.offsetHeight
    const collapsed = this.element.getBoundingClientRect().height

    this.element.classList.toggle(COLLAPSED_CLASS, wasCollapsed)
    this.queueEnableTransitions()

    this.collapsedDelta = Math.max(0, Math.round(expanded - collapsed))
    return this.collapsedDelta
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
    this.lockTransition()
    this.element.classList.toggle(COLLAPSED_CLASS, collapsed)
  }

  lockTransition() {
    this.transitionLocked = true
    if (this.lockTimer != null) window.clearTimeout(this.lockTimer)
    this.lockTimer = window.setTimeout(() => {
      this.lockTimer = null
      this.transitionLocked = false
    }, TRANSITION_LOCK_MS)
  }

  handleTransitionEnd(event) {
    if (!this.transitionLocked) return
    if (event.target !== this.element && !this.element.contains(event.target)) return
    if (this.lockTimer != null) {
      window.clearTimeout(this.lockTimer)
      this.lockTimer = null
    }
    this.transitionLocked = false
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
