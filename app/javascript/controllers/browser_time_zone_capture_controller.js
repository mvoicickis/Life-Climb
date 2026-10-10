import { Controller } from "@hotwired/stimulus"
import { detectedBrowserTimeZone } from "browser_timezone"

// One-shot: save browser IANA zone when notification_preference.time_zone is missing.
export default class extends Controller {
  static values = {
    url: String,
    needed: Boolean
  }

  connect() {
    if (!this.neededValue || !this.urlValue) return

    const zone = detectedBrowserTimeZone()
    if (!zone) return

    fetch(this.urlValue, {
      method: "PATCH",
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
      },
      body: JSON.stringify({ time_zone: zone })
    }).catch(() => {
      /* Silent — cron nudges stay off until next visit or subscribe. */
    })
  }
}
