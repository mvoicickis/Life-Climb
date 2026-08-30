import { Controller } from "@hotwired/stimulus"

// Shows optional contact field only when "OK to contact" is checked.
export default class extends Controller {
  static targets = ["optIn", "panel", "input", "appVersion"]

  connect() {
    this.syncAppVersion()
    this.sync()
  }

  syncAppVersion() {
    if (!this.hasAppVersionTarget) return

    const meta = document.querySelector('meta[name="app-version"]')
    if (meta?.content) this.appVersionTarget.value = meta.content
  }

  sync() {
    const on = this.hasOptInTarget && this.optInTarget.checked
    if (this.hasPanelTarget) this.panelTarget.hidden = !on
    if (!on && this.hasInputTarget) {
      // Keep account email default for logged-in users; clear anonymous free-text.
      if (this.inputTarget.dataset.keepDefault !== "true") {
        this.inputTarget.value = ""
      }
    }
  }
}
