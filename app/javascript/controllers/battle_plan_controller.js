import { Controller } from "@hotwired/stimulus"

// Filters Daily Battle Plan items by the selected life-aspect tag.
export default class extends Controller {
  static targets = ["tag", "item", "aspectField", "empty"]
  static values = { aspect: String }

  connect() {
    this.filter()
  }

  select(event) {
    const key = event.currentTarget.dataset.aspect
    if (!key) return

    this.aspectValue = key
    this.tagTargets.forEach((el) => {
      el.classList.toggle("is-active", el.dataset.aspect === key)
      el.setAttribute("aria-checked", el.dataset.aspect === key ? "true" : "false")
    })
    this.aspectFieldTargets.forEach((field) => {
      field.value = key
    })
    this.filter()
  }

  filter() {
    const key = this.aspectValue
    let visible = 0
    this.itemTargets.forEach((el) => {
      const show = el.dataset.aspect === key
      el.hidden = !show
      if (show) visible += 1
    })
    if (this.hasEmptyTarget) {
      this.emptyTarget.hidden = visible > 0
    }
  }
}
