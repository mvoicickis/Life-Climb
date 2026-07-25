import { Controller } from "@hotwired/stimulus"

// Filters Daily Battle Plan by life-aspect tag and surfaces open counts elsewhere.
export default class extends Controller {
  static targets = ["tag", "item", "aspectField", "empty", "badge", "waiting", "waitingList"]
  static values = { aspect: String }

  connect() {
    this.filter()
    this.refreshWaiting()
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
    this.refreshWaiting()
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

  openCounts() {
    const counts = {}
    this.itemTargets.forEach((el) => {
      if (el.dataset.open !== "true") return
      const key = el.dataset.aspect
      counts[key] = (counts[key] || 0) + 1
    })
    return counts
  }

  refreshWaiting() {
    const counts = this.openCounts()
    const selected = this.aspectValue

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

    if (!this.hasWaitingTarget || !this.hasWaitingListTarget) return

    const others = Object.entries(counts).filter(([key, count]) => key !== selected && count > 0)
    this.waitingListTarget.innerHTML = ""

    if (others.length === 0) {
      this.waitingTarget.hidden = true
      return
    }

    this.waitingTarget.hidden = false
    others.forEach(([key, count]) => {
      const source = this.tagTargets.find((t) => t.dataset.aspect === key)
      if (!source) return
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "lp-aspect-tag has-open"
      btn.dataset.aspect = key
      btn.dataset.action = "battle-plan#select"
      btn.innerHTML = `${source.querySelector("span[aria-hidden]")?.outerHTML || ""} ${this.tagLabel(source)} <span class="lp-aspect-badge">${count}</span>`
      this.waitingListTarget.appendChild(btn)
    })
  }

  tagLabel(tagEl) {
    const clone = tagEl.cloneNode(true)
    clone.querySelectorAll(".lp-aspect-badge, span[aria-hidden]").forEach((n) => n.remove())
    return clone.textContent.trim()
  }
}
