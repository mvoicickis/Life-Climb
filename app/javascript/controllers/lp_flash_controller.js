import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (this.element.classList.contains("lp-flash--notice")) {
      this.autoHideTimer = window.setTimeout(() => this.dismiss(), 4000)
    }
  }

  disconnect() {
    this.clearAutoHide()
  }

  dismiss() {
    this.clearAutoHide()
    this.element.classList.add("is-dismissed")
    this.element.setAttribute("hidden", "")
  }

  clearAutoHide() {
    if (this.autoHideTimer) {
      window.clearTimeout(this.autoHideTimer)
      this.autoHideTimer = null
    }
  }
}
