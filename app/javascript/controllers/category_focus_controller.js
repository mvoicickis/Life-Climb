import { Controller } from "@hotwired/stimulus"

// Expedition drill-down: Practice Category list ↔ one focused category.
// Level A = list. Level B = entered folder. Path crumb exits.
export default class extends Controller {
  static targets = ["list", "panel", "crumb", "pathTitle"]
  static values = {
    initialId: { type: String, default: "" },
    activeId: { type: String, default: "" }
  }

  connect() {
    if (this.initialIdValue) {
      this.enterById(this.initialIdValue, { animate: false })
    } else {
      this.showList({ animate: false })
    }
  }

  enter(event) {
    const id = event.params?.id?.toString() || event.currentTarget?.dataset?.categoryFocusIdParam
    if (!id) return
    this.enterById(id, { animate: true })
  }

  exit(event) {
    event?.preventDefault()
    this.showList({ animate: true })
  }

  enterById(id, { animate } = { animate: true }) {
    const panel = this.panelTargets.find((el) => el.dataset.categoryId === String(id))
    if (!panel) return

    this.activeIdValue = String(id)
    this.element.classList.add("is-category-focus")
    this.element.classList.remove("is-categories")
    this.element.dataset.focusCategoryId = String(id)

    if (this.hasListTarget) {
      this.listTarget.hidden = true
      this.listTarget.setAttribute("aria-hidden", "true")
      this.listTarget.classList.add("is-exited")
      if (animate) this.listTarget.classList.add("is-exiting")
    }

    this.panelTargets.forEach((el) => {
      const active = el === panel
      el.hidden = !active
      el.setAttribute("aria-hidden", active ? "false" : "true")
      el.classList.toggle("is-entered", active)
      el.classList.toggle("is-animating", active && animate)
    })
    if (animate && panel) {
      requestAnimationFrame(() => panel.classList.remove("is-animating"))
    }

    if (this.hasCrumbTarget) this.crumbTarget.hidden = false
    if (this.hasPathTitleTarget) this.pathTitleTarget.hidden = true
  }

  showList({ animate } = { animate: true }) {
    this.activeIdValue = ""
    this.element.classList.remove("is-category-focus")
    this.element.classList.add("is-categories")
    delete this.element.dataset.focusCategoryId

    this.panelTargets.forEach((el) => {
      el.hidden = true
      el.setAttribute("aria-hidden", "true")
      el.classList.remove("is-entered")
    })

    if (this.hasListTarget) {
      this.listTarget.hidden = false
      this.listTarget.setAttribute("aria-hidden", "false")
      this.listTarget.classList.remove("is-exiting", "is-exited")
      if (animate) {
        this.listTarget.classList.add("is-entering")
        requestAnimationFrame(() => this.listTarget.classList.remove("is-entering"))
      }
    }

    if (this.hasCrumbTarget) this.crumbTarget.hidden = true
    if (this.hasPathTitleTarget) this.pathTitleTarget.hidden = false
  }
}
