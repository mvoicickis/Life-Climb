import { Controller } from "@hotwired/stimulus"

// Camp command table — switch Today's Orders / All Practices panels.
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = {
    view: { type: String, default: "orders" }
  }

  connect() {
    this.applyView()
  }

  showOrders(event) {
    event?.preventDefault()
    this.viewValue = "orders"
    this.applyView()
  }

  showAll(event) {
    event?.preventDefault()
    this.viewValue = "all"
    this.applyView()
  }

  prepare(event) {
    event?.preventDefault()
    const id = event?.params?.id || this.element.dataset.prepareId
    if (!id) return
    const details = document.getElementById(`rpg-add-practice-${id}`)
    const summary = details?.querySelector("summary.lp-rpg-practice-add")
    if (!details || !summary) return
    if (!details.open) summary.click()
    summary.scrollIntoView({ block: "nearest", inline: "nearest" })
  }

  applyView() {
    const view = this.viewValue === "all" ? "all" : "orders"
    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.view === view
      tab.classList.toggle("is-active", active)
      tab.setAttribute("aria-selected", active ? "true" : "false")
      tab.tabIndex = active ? 0 : -1
    })
    this.panelTargets.forEach((panel) => {
      const active = panel.dataset.view === view
      panel.hidden = !active
      panel.classList.toggle("is-active", active)
      panel.setAttribute("aria-hidden", active ? "false" : "true")
    })
  }
}
