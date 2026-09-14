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
}
