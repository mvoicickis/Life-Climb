import { Controller } from "@hotwired/stimulus"

// Snap Plan Rail: only full cards visible; desktop arrows when overflowing.
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
    this.fitFullCardsOnly()
    this.ensureFocusedVisible()
    this.syncArrows()
  }

  // Shrink the track viewport so leftover width is empty gutter — never a card peek.
  // End spacer lets the last card snap fully into view only when content overflows.
  fitFullCardsOnly() {
    if (!this.hasTrackTarget) return

    const track = this.trackTarget
    const item = track.querySelector(":scope > li")
    if (!item) return

    const styles = getComputedStyle(track)
    const gap = parseFloat(styles.columnGap || styles.gap || "0") || 0
    const cardWidth = item.getBoundingClientRect().width
    if (cardWidth <= 0) return

    const step = cardWidth + gap
    const items = track.querySelectorAll(":scope > li")
    const contentWidth = items.length * cardWidth + Math.max(0, items.length - 1) * gap

    const currentGutter =
      parseFloat(getComputedStyle(this.element).getPropertyValue("--lp-rail-gutter-end")) || 0
    // Available width is the track before the dynamic full-card gutter.
    const available = track.clientWidth + currentGutter
    const count = Math.max(1, Math.floor((available + gap) / step))
    const used = count * step - gap
    const leftover = Math.max(0, available - used)
    this.element.style.setProperty("--lp-rail-gutter-end", `${leftover}px`)

    const viewport = Math.max(cardWidth, available - leftover)
    const overflowing = contentWidth > viewport + 1
    track.style.setProperty(
      "--lp-rail-end-spacer",
      overflowing ? `${Math.max(0, viewport - cardWidth)}px` : "0px"
    )
  }

  handleWheel(event) {
    if (!this.hasTrackTarget) return
    const track = this.trackTarget
    const maxScroll = track.scrollWidth - track.clientWidth
    if (maxScroll <= 1) return

    // Map vertical wheel (or shift+wheel) to horizontal scroll when the rail overflows.
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
