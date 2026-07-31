import { Controller } from "@hotwired/stimulus"

// Snap Plan Rail: track fills space between nav columns; arrows when overflowing.
export default class extends Controller {
  static targets = ["track", "prev", "next"]

  connect() {
    this.onScroll = () => this.syncArrows()
    this.onResize = () => this.layout()
    this.onWheel = (event) => this.handleWheel(event)

    if (this.hasTrackTarget) {
      this.trackTarget.addEventListener("scroll", this.onScroll, { passive: true })
      this.trackTarget.addEventListener("wheel", this.onWheel, { passive: false })
    }
    this.resizeObserver = new ResizeObserver(this.onResize)
    this.resizeObserver.observe(this.element)
    if (this.hasTrackTarget) this.resizeObserver.observe(this.trackTarget)

    requestAnimationFrame(() => this.layout())
  }

  disconnect() {
    this.trackTarget?.removeEventListener("scroll", this.onScroll)
    this.trackTarget?.removeEventListener("wheel", this.onWheel)
    this.resizeObserver?.disconnect()
  }

  layout() {
    this.ensureFocusedVisible()
    this.syncArrows()
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
    window.setTimeout(() => this.syncArrows(), reduce ? 0 : 320)
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

    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    item.scrollIntoView({
      inline: "start",
      block: "nearest",
      behavior: reduce ? "auto" : "smooth"
    })
  }

  syncArrows() {
    if (!this.hasTrackTarget) return

    const track = this.trackTarget
    const maxScroll = track.scrollWidth - track.clientWidth
    const overflowing = maxScroll > 1
    this.element.classList.toggle("is-overflowing", overflowing)

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
}
