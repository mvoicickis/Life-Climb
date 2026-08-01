import { Controller } from "@hotwired/stimulus"

// Shared horizontal snap-scroll for Paths, Now battles, and Camps rows.
// Path rail also hosts the inline focus panel actions.
export default class extends Controller {
  static targets = ["track", "prev", "next", "focusPanel"]
  static values = { goal: Number, journey: Number, scope: String }

  connect() {
    this.onScroll = () => {
      this.syncArrows()
      this.persistScroll()
    }
    this.onResize = () => this.layout()
    this.onWheel = (event) => this.handleWheel(event)
    this.onBeforeVisit = () => this.persistScroll()

    if (this.hasTrackTarget) {
      this.trackTarget.addEventListener("scroll", this.onScroll, { passive: true })
      this.trackTarget.addEventListener("wheel", this.onWheel, { passive: false })
    }
    document.addEventListener("turbo:before-visit", this.onBeforeVisit)

    this.resizeObserver = new ResizeObserver(this.onResize)
    this.resizeObserver.observe(this.element)
    if (this.hasTrackTarget) this.resizeObserver.observe(this.trackTarget)

    requestAnimationFrame(() => this.layout())
  }

  disconnect() {
    this.persistScroll()
    this.trackTarget?.removeEventListener("scroll", this.onScroll)
    this.trackTarget?.removeEventListener("wheel", this.onWheel)
    document.removeEventListener("turbo:before-visit", this.onBeforeVisit)
    this.resizeObserver?.disconnect()
  }

  layout() {
    this.restoreScroll()
    this.ensureFocusedVisible()
    this.syncArrows()
  }

  scrollStorageKey() {
    const journey = this.journeyValue || 0
    const goal = this.goalValue || 0
    if (this.hasScopeValue && this.scopeValue) {
      return `lp-snap-scroll:${this.scopeValue}:${journey}:${goal}`
    }
    return `lp-path-rail-scroll:${journey}:${goal}`
  }

  persistScroll() {
    if (!this.hasTrackTarget) return
    try {
      sessionStorage.setItem(this.scrollStorageKey(), String(this.trackTarget.scrollLeft))
    } catch (_) {
      /* private mode */
    }
  }

  rememberScrollFromClick(event) {
    if (event.target.closest("a.lp-rpg-path")) this.persistScroll()
  }

  restoreScroll() {
    if (!this.hasTrackTarget) return
    let raw = null
    try {
      raw = sessionStorage.getItem(this.scrollStorageKey())
    } catch (_) {
      return
    }
    if (raw == null) return
    const left = Number.parseFloat(raw)
    if (Number.isNaN(left)) return
    this.trackTarget.scrollLeft = left
  }

  handleWheel(event) {
    if (!this.hasTrackTarget) return
    const track = this.trackTarget
    const maxScroll = track.scrollWidth - track.clientWidth
    if (maxScroll <= 1) return

    const delta =
      Math.abs(event.deltaX) > Math.abs(event.deltaY)
        ? event.deltaX
        : event.shiftKey || Math.abs(event.deltaY) > 0
          ? event.deltaY
          : 0

    if (delta === 0) return

    const atStart = track.scrollLeft <= 1
    const atEnd = track.scrollLeft >= maxScroll - 1
    if ((delta < 0 && atStart) || (delta > 0 && atEnd)) return

    event.preventDefault()
    track.scrollBy({ left: delta, behavior: "auto" })
    this.syncArrows()
  }

  prev(event) {
    event.preventDefault()
    this.scrollByCards(-1)
  }

  next(event) {
    event.preventDefault()
    this.scrollByCards(1)
  }

  scrollByCards(direction) {
    if (!this.hasTrackTarget) return
    const step = this.cardStep()
    if (step <= 0) return

    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.trackTarget.scrollBy({
      left: direction * step,
      behavior: reduce ? "auto" : "smooth"
    })
    window.setTimeout(() => {
      this.syncArrows()
      this.persistScroll()
    }, reduce ? 0 : 320)
  }

  cardStep() {
    const item = this.trackTarget.querySelector(":scope > li")
    if (!item) return 0
    const styles = getComputedStyle(this.trackTarget)
    const gap = parseFloat(styles.columnGap || styles.gap || "0") || 0
    return item.getBoundingClientRect().width + gap
  }

  ensureFocusedVisible() {
    if (!this.hasTrackTarget) return
    const focused =
      this.trackTarget.querySelector(".lp-rpg-path.is-focus") ||
      this.trackTarget.querySelector("li.is-focus")
    const item = focused?.closest("li") || focused
    if (!item) return

    const track = this.trackTarget
    const trackRect = track.getBoundingClientRect()
    const itemRect = item.getBoundingClientRect()
    const fullyVisible =
      itemRect.left >= trackRect.left - 1 && itemRect.right <= trackRect.right + 1

    if (fullyVisible) return

    // Instant jump after Turbo so scroll does not animate back to the start.
    item.scrollIntoView({
      inline: "nearest",
      block: "nearest",
      behavior: "auto"
    })
    this.persistScroll()
  }

  syncArrows() {
    if (!this.hasTrackTarget) return

    const track = this.trackTarget
    const maxScroll = track.scrollWidth - track.clientWidth
    const overflowing = maxScroll > 1
    const rail = this.element.querySelector(".lp-rpg-plan-rail") || this.element
    rail.classList.toggle("is-overflowing", overflowing)
    this.element.classList.toggle("is-overflowing", overflowing)
    track.classList.toggle("is-overflowing", overflowing)

    const atStart = track.scrollLeft <= 1
    const atEnd = track.scrollLeft >= maxScroll - 1

    if (this.hasPrevTarget) {
      this.prevTarget.hidden = !overflowing || atStart
      this.prevTarget.disabled = !overflowing || atStart
    }
    if (this.hasNextTarget) {
      this.nextTarget.hidden = !overflowing || atEnd
      this.nextTarget.disabled = !overflowing || atEnd
    }
  }

  placeCheckpoint(event) {
    event.preventDefault()
    const details =
      document.querySelector("#rpg-add-checkpoint") ||
      document.querySelector(".lp-rpg-add.is-checkpoint")
    if (!details) return
    details.open = true
    details.scrollIntoView({ behavior: "smooth", block: "center" })
    const input = details.querySelector("input[name='title'], input, textarea")
    input?.focus()
  }

  editPath(event) {
    event.preventDefault()
    const focused = this.element.querySelector("li.is-focus[data-controller~='plan-card-menu']")
    if (!focused) return
    const menu = this.application.getControllerForElementAndIdentifier(focused, "plan-card-menu")
    if (menu?.edit) {
      menu.edit({ preventDefault() {}, stopPropagation() {} })
      return
    }
    focused.querySelector("[data-action*='plan-card-menu#edit']")?.click()
  }

  viewProgress(event) {
    event.preventDefault()
    const climb =
      document.querySelector(".lp-rpg-climb") ||
      document.querySelector(".lp-rpg-world.is-trail")
    climb?.scrollIntoView({ behavior: "smooth", block: "start" })
  }
}
