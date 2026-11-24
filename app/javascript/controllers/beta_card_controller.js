import { Controller } from "@hotwired/stimulus"
import { isAndroid } from "push_subscription"

export default class extends Controller {
  static targets = [ "defaultPanel", "androidPanel" ]

  connect() {
    if (!isAndroid()) return

    this.element.classList.add("is-android")
    this.defaultPanelTarget.hidden = true
    this.androidPanelTarget.hidden = false
  }
}
