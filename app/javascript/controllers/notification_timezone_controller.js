import { Controller } from "@hotwired/stimulus"
import { detectedBrowserTimeZone } from "browser_timezone"

// Auto-capture the browser IANA timezone into a hidden field and persist on visit.
export default class extends Controller {
  static targets = ["field"]
  static values = {
    url: String,
    current: String
  }

  connect() {
    const zone = this.detectedZone()
    if (!zone) return

    if (this.hasFieldTarget) this.fieldTarget.value = zone

    if (zone !== (this.currentValue || "")) {
      this.persist(zone)
    }
  }

  detectedZone() {
    return detectedBrowserTimeZone()
  }

  async persist(zone) {
    if (!this.urlValue) return

    const token = document.querySelector("meta[name='csrf-token']")?.content
    try {
      await fetch(this.urlValue, {
        method: "PATCH",
        credentials: "same-origin",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": token || ""
        },
        body: JSON.stringify({
          notification_preference: { time_zone: zone }
        })
      })
      this.currentValue = zone
    } catch (error) {
      console.error(error)
    }
  }
}
