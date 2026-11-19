import { Controller } from "@hotwired/stimulus"
import { setEnabled } from "lib/lp_sound"

// You → App → Sound toggle. Patches users.sound_enabled and updates lp_sound.
export default class extends Controller {
  static targets = ["switch"]
  static values = {
    url: String,
    enabled: { type: Boolean, default: true },
    notSaved: { type: String, default: "Not saved. Tap to try again." }
  }

  connect() {
    this.syncSwitch()
    setEnabled(this.enabledValue)
  }

  async toggle(event) {
    event.preventDefault()
    if (this.saving) return

    const next = !this.enabledValue
    this.enabledValue = next
    this.syncSwitch()
    setEnabled(next)

    this.saving = true
    const token = document.querySelector("meta[name='csrf-token']")?.content
    const body = new URLSearchParams()
    body.set("user[sound_enabled]", next ? "1" : "0")
    body.set("authenticity_token", token || "")

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": token || "",
          "X-Requested-With": "XMLHttpRequest"
        },
        body,
        credentials: "same-origin"
      })
      if (!response.ok) throw new Error("not_ok")
    } catch (_err) {
      this.enabledValue = !next
      this.syncSwitch()
      setEnabled(this.enabledValue)
      window.alert(this.notSavedValue)
    } finally {
      this.saving = false
    }
  }

  syncSwitch() {
    if (!this.hasSwitchTarget) return
    this.switchTarget.classList.toggle("is-on", this.enabledValue)
    this.switchTarget.setAttribute("aria-checked", this.enabledValue ? "true" : "false")
  }
}
