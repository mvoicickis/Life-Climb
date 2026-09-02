import { Controller } from "@hotwired/stimulus"
import { detectedBrowserTimeZone } from "browser_timezone"

// Sets a hidden time_zone field on connect (registration form).
export default class extends Controller {
  static targets = ["field"]

  connect() {
    const zone = detectedBrowserTimeZone()
    if (!zone || !this.hasFieldTarget) return

    this.fieldTarget.value = zone
  }
}
