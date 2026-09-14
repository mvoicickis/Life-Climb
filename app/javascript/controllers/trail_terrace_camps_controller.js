import { Controller } from "@hotwired/stimulus"

// Client-side pair paging for camps on the open terrace.
export default class extends Controller {
  static targets = ["camp", "prev", "next", "dot", "stagePill", "nav", "dots"]
  static values = {
    page: { type: Number, default: 0 },
    pageSize: { type: Number, default: 2 },
    pageCount: { type: Number, default: 0 }
  }

  connect() {
    this.pageValue = 0
    this.renderPage()
    this._layoutArrows = this.layoutArrows.bind(this)
    this._arrowResizeObserver = new ResizeObserver(this._layoutArrows)
    this._arrowResizeObserver.observe(this.element)
    const map = this.element.closest(".trail-stages")
    if (map) this._arrowResizeObserver.observe(map)
  }

  disconnect() {
    this._arrowResizeObserver?.disconnect()
  }

  prev(event) {
    event.preventDefault()
    if (this.pageValue <= 0) return
    this.pageValue -= 1
    this.renderPage()
  }

  next(event) {
    event.preventDefault()
    if (this.pageValue >= this.totalPages - 1) return
    this.pageValue += 1
    this.renderPage()
  }

  get totalPages() {
    if (this.pageCountValue > 0) return this.pageCountValue

    return Math.ceil(this.campTargets.length / this.pageSizeValue)
  }

  renderPage() {
    const page = this.pageValue
    const lastPage = this.totalPages - 1
    if (page > lastPage) {
      this.pageValue = lastPage
      return this.renderPage()
    }

    this.campTargets.forEach((camp, index) => {
      const campPage = Math.floor(index / this.pageSizeValue)
      camp.hidden = campPage !== page
    })

    this.stagePillTargets.forEach((pill, pillIndex) => {
      pill.hidden = pillIndex !== page
    })

    this.syncChrome()
    this.layoutArrows()
  }

  syncChrome() {
    const multiPage = this.totalPages > 1
    const page = this.pageValue

    if (this.hasNavTarget) this.navTarget.hidden = !multiPage
    if (this.hasDotsTarget) {
      this.dotsTarget.hidden = !multiPage
      this.dotsTarget.setAttribute("aria-hidden", multiPage ? "false" : "true")
    }

    if (!multiPage) return

    if (this.hasPrevTarget) this.prevTarget.hidden = page <= 0
    if (this.hasNextTarget) this.nextTarget.hidden = page >= this.totalPages - 1

    this.dotTargets.forEach((dot, index) => {
      const active = index === page
      dot.classList.toggle("is-active", active)
      dot.setAttribute("aria-current", active ? "true" : "false")
    })
  }

  layoutArrows() {
    if (this.totalPages <= 1) {
      this.element.classList.remove("is-terrace-camp-arrows-dots")
      this.element.style.removeProperty("--lp-terrace-dots-cluster-half")
      return
    }

    this.element.classList.remove("is-terrace-camp-arrows-dots")
    this.element.style.removeProperty("--lp-terrace-dots-cluster-half")

    this.withArrowsVisibleForLayout(() => {
      if (this.arrowsNeedDotsRow()) {
        if (this.hasDotsTarget) {
          this.dotsTarget.hidden = false
          const half = this.dotsTarget.getBoundingClientRect().width / 2
          if (half > 0) {
            this.element.style.setProperty("--lp-terrace-dots-cluster-half", `${half}px`)
          }
        }
        this.element.classList.add("is-terrace-camp-arrows-dots")
      }
    })

    this.syncChrome()
  }

  withArrowsVisibleForLayout(callback) {
    const prevHidden = this.hasPrevTarget ? this.prevTarget.hidden : true
    const nextHidden = this.hasNextTarget ? this.nextTarget.hidden : true
    if (this.hasPrevTarget) this.prevTarget.hidden = false
    if (this.hasNextTarget) this.nextTarget.hidden = false

    callback()

    if (this.hasPrevTarget) this.prevTarget.hidden = prevHidden
    if (this.hasNextTarget) this.nextTarget.hidden = nextHidden
  }

  arrowsNeedDotsRow() {
    const map = this.element.closest(".lp-trail__map") || this.element.closest(".trail-stages")
    if (!map) return false

    const mapRect = map.getBoundingClientRect()
    const safe = 12
    const arrows = [ this.prevTarget, this.nextTarget ].filter(Boolean)
    const camps = this.visibleCampPegs()

    for (const arrow of arrows) {
      const rect = arrow.getBoundingClientRect()
      if (rect.width <= 0) continue

      if (rect.left < mapRect.left + safe - 0.5 || rect.right > mapRect.right - safe + 0.5) {
        return true
      }

      for (const peg of camps) {
        if (this.rectsOverlap(rect, peg.getBoundingClientRect())) return true
      }
    }

    return false
  }

  visibleCampPegs() {
    return this.campTargets
      .filter((camp) => !camp.hidden)
      .map((camp) => camp.querySelector(".lp-trail-camp__peg"))
      .filter(Boolean)
  }

  rectsOverlap(a, b) {
    return a.left < b.right - 0.5 && a.right > b.left + 0.5 && a.top < b.bottom - 0.5 && a.bottom > b.top + 0.5
  }
}
