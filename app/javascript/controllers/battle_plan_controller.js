import { Controller } from "@hotwired/stimulus"

// Filters Daily Battle Plan by life-aspect tag. Mission CTA stays independent.
export default class extends Controller {
  static targets = ["tag", "item", "aspectField", "empty", "badge", "focusLabel", "addForm"]
  static values = {
    aspect: String,
    focusTemplate: { type: String, default: "Focus list · %{area}" }
  }

  connect() {
    this.filter()
    this.refreshBadges()
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
    if (this.hasFocusLabelTarget) {
      const label = event.currentTarget.dataset.label || key
      this.focusLabelTarget.textContent = this.focusTemplateValue.replace("%{area}", label)
    }
    this.filter()
    this.refreshBadges()
  }

  toggleAdd() {
    if (!this.hasAddFormTarget) return
    this.addFormTarget.hidden = !this.addFormTarget.hidden
    if (!this.addFormTarget.hidden) {
      const input = this.addFormTarget.querySelector("input[type='text']")
      input?.focus()
    }
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

  refreshBadges() {
    const counts = {}
    this.itemTargets.forEach((el) => {
      if (el.dataset.open !== "true") return
      const key = el.dataset.aspect
      counts[key] = (counts[key] || 0) + 1
    })

    this.tagTargets.forEach((tag) => {
      const key = tag.dataset.aspect
      const count = counts[key] || 0
      tag.classList.toggle("has-open", count > 0)
      const badge = tag.querySelector("[data-battle-plan-target='badge']")
      if (badge) {
        badge.textContent = count
        badge.hidden = count === 0
      }
    })
  }
}
